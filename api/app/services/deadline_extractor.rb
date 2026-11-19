# Finds deadlines and key dates in legal documents and turns them into tasks.
#
# Rules mode (default, no AI service needed) reads each sentence and looks for:
#   - an explicit date next to a deadline cue: "on or before March 15, 2027", "no later than 2027-03-15",
#     "the hearing is scheduled for 4 February 2027"
#   - a relative period: "within 20 days of service", "within thirty (30) business days after receipt",
#     counted from a base date (for example the date the document was served)
# A date without a cue ("dated January 1, 2026") is ignored on purpose.
class DeadlineExtractor
  MONTHS = Date::MONTHNAMES.compact.map(&:downcase)
  MONTH = "(?:#{MONTHS.join('|')}|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\\.?"
  CUE = /\b(?:on or before|no later than|not later than|by|before|due(?: on| by)?|deadline(?: is| of)?|scheduled for|hearing (?:is |will be )?(?:on|set for)|must be (?:filed|served|delivered|paid) (?:on|by))\s*$/i
  DATE_PATTERNS = [
    /\b(#{MONTH})\s+(\d{1,2}),?\s+(\d{4})\b/i,            # March 15, 2027
    /\b(\d{1,2})\s+(#{MONTH})\s+(\d{4})\b/i,               # 15 March 2027
    /\b(\d{4})-(\d{2})-(\d{2})\b/                          # 2027-03-15
  ].freeze
  NUMBER_WORDS = %w[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen
                    seventeen eighteen nineteen twenty].each_with_index.to_h
                    .merge("thirty" => 30, "forty" => 40, "forty-five" => 45, "sixty" => 60, "ninety" => 90)
  RELATIVE = /\bwithin\s+(?:(\d{1,3})|([a-z-]+)(?:\s*\((\d{1,3})\))?)\s+(business\s+|calendar\s+)?days?\s+(?:of|after|from|following)\s+(?:the\s+)?([a-z ]{3,40}?)(?=[,.;]|\s+(?:to|the|you|we|and)\b|$)/i
  ACTION = /\b(file|serve|deliver|respond|reply|pay|submit|provide|produce|appeal|attend|complete|sign|return)\w*\b(.{0,80})/i

  Deadline = Struct.new(:due_on, :title, :evidence, :source, keyword_init: true)

  def self.call(text, base_date: Date.current) = new(text, base_date).call

  def initialize(text, base_date)
    @text = text.to_s
    @base_date = base_date
  end

  def call
    sentences.flat_map { |s| explicit_dates(s) + relative_dates(s) }
             .uniq { |d| [ d.due_on, d.title ] }
             .sort_by(&:due_on)
  end

  def self.title_for(sentence)
    if (m = sentence.match(ACTION))
      phrase = "#{m[1].capitalize}#{m[0][m[1].length..]}".split(/\s+(?:within|by|on or before|no later than|before)\b/i).first
      phrase.strip.sub(/[,.;:]+\z/, "")[0, 120]
    else
      sentence.strip[0, 120]
    end
  end

  def self.business_days_after(date, days)
    d = date
    days.times do
      d += 1
      d += 1 while d.saturday? || d.sunday?
    end
    d
  end

  private

  def sentences
    @text.gsub(/\s+/, " ").split(/(?<=[.;!?])\s+(?=[A-Z(])/)
  end

  def explicit_dates(sentence)
    DATE_PATTERNS.flat_map do |pattern|
      sentence.to_enum(:scan, pattern).filter_map do
        match = Regexp.last_match
        next unless sentence[0...match.begin(0)] =~ CUE
        date = parse_date(match)
        Deadline.new(due_on: date, title: self.class.title_for(sentence), evidence: sentence.strip, source: "rules") if date
      end
    end
  end

  def relative_dates(sentence)
    sentence.to_enum(:scan, RELATIVE).filter_map do
      m = Regexp.last_match
      days = (m[1] || m[3]).to_i
      days = NUMBER_WORDS[m[2].to_s.downcase] if days.zero? && m[2]
      next unless days&.positive?
      due = m[4].to_s.strip.casecmp?("business") ? self.class.business_days_after(@base_date, days) : @base_date + days
      Deadline.new(due_on: due, title: self.class.title_for(sentence), evidence: sentence.strip, source: "rules")
    end
  end

  def parse_date(match)
    parts = match.captures
    if parts[0] =~ /\A\d{4}\z/
      Date.new(parts[0].to_i, parts[1].to_i, parts[2].to_i)
    elsif parts[0] =~ /\A\d/
      Date.new(parts[2].to_i, month_number(parts[1]), parts[0].to_i)
    else
      Date.new(parts[2].to_i, month_number(parts[0]), parts[1].to_i)
    end
  rescue Date::Error, ArgumentError
    nil
  end

  def month_number(name)
    key = name.downcase.delete(".")[0, 3]
    MONTHS.index { |m| m.start_with?(key) } + 1
  end
end
