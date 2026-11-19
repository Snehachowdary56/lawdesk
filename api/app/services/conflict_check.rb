# Conflict-of-interest check: before taking a new client, a firm must find anyone with that name among
# its existing clients and the opposing (adverse) parties in its matters. Names are messy ("ACME Corp."
# vs "Acme Corporation", typos like "Jonh"), so this uses normalisation plus two similarity measures:
#   - Levenshtein edit distance (dynamic programming, O(n*m) time, O(min(n, m)) memory)
#   - token overlap (Jaccard similarity of the words in the names)
class ConflictCheck
  SUFFIXES = %w[inc incorporated corp corporation co company ltd limited llc llp lp plc].freeze
  THRESHOLD = 0.8

  Match = Struct.new(:name, :role, :record_type, :record_id, :score, :reason, keyword_init: true)

  def self.call(name) = new(name).call

  def initialize(name)
    @query = self.class.normalize(name)
  end

  def call
    return [] if @query.empty?

    candidates.filter_map { |c| match_for(c) }.sort_by { |m| -m.score }
  end

  def self.normalize(name)
    words = name.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").split
    words.reject { |w| SUFFIXES.include?(w) }.join(" ")
  end

  # Classic dynamic programming edit distance, keeping only two rows.
  def self.levenshtein(a, b)
    a, b = b, a if a.length < b.length
    previous = (0..b.length).to_a
    a.each_char.with_index(1) do |ca, i|
      current = [ i ]
      b.each_char.with_index(1) do |cb, j|
        current << [ previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (ca == cb ? 0 : 1) ].min
      end
      previous = current
    end
    previous.last
  end

  def self.similarity(a, b)
    return 1.0 if a == b
    return 0.0 if a.empty? || b.empty?

    edit = 1.0 - levenshtein(a, b).fdiv([ a.length, b.length ].max)
    ta = a.split.to_set
    tb = b.split.to_set
    jaccard = (ta & tb).size.fdiv((ta | tb).size)
    [ edit, jaccard ].max
  end

  private

  def candidates
    clients = Client.pluck(:id, :name).map { |id, n| { name: n, role: "existing client", type: "Client", id: id } }
    adverse = Matter.where.not(adverse_party: [ nil, "" ]).pluck(:id, :adverse_party)
                    .map { |id, n| { name: n, role: "adverse party", type: "Matter", id: id } }
    clients + adverse
  end

  def match_for(candidate)
    score = self.class.similarity(@query, self.class.normalize(candidate[:name]))
    return if score < THRESHOLD

    reason = score == 1.0 ? "same name" : "similar name"
    Match.new(name: candidate[:name], role: candidate[:role], record_type: candidate[:type],
              record_id: candidate[:id], score: score.round(3), reason: reason)
  end
end
