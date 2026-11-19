require "net/http"
require "json"

# Optional AI mode: asks a large language model (Anthropic Messages API) to find deadlines, then applies
# guardrails before anything becomes a task:
#   - the reply must be valid JSON in the expected shape
#   - every deadline must quote a sentence that really appears in the document (no invented deadlines)
#   - every date must be a real date
# Anything that fails a check is dropped and counted. With no API key, callers use the rules instead.
class LlmDeadlineExtractor
  ENDPOINT = URI("https://api.anthropic.com/v1/messages")
  PROMPT = <<~PROMPT.freeze
    You read legal documents and list every deadline or scheduled date a lawyer must act on.
    Reply with JSON only: {"deadlines":[{"due_on":"YYYY-MM-DD","title":"short action","quote":"exact sentence from the document"}]}
    Count relative periods ("within 20 days of service") from the base date given. Do not include dates that are not deadlines.
  PROMPT

  Result = Struct.new(:deadlines, :rejected, keyword_init: true)

  def self.available? = ENV["ANTHROPIC_API_KEY"].present? && ENV["LLM_MODEL"].present?

  def initialize(transport: method(:post))
    @transport = transport
  end

  def call(text, base_date:)
    raw = @transport.call(system: PROMPT, user: "Base date: #{base_date.iso8601}\n\nDocument:\n#{text}")
    items = JSON.parse(raw.to_s[/\{.*\}/m] || "{}").fetch("deadlines", [])
    normalized = text.gsub(/\s+/, " ")
    kept, rejected = items.partition { |i| valid?(i, normalized) }
    deadlines = kept.map do |i|
      DeadlineExtractor::Deadline.new(due_on: Date.iso8601(i["due_on"]), title: i["title"].to_s.strip[0, 120],
                                      evidence: i["quote"].to_s.strip, source: "llm")
    end
    Result.new(deadlines: deadlines.sort_by(&:due_on), rejected: rejected.size)
  rescue JSON::ParserError
    Result.new(deadlines: [], rejected: 1)
  end

  private

  def valid?(item, normalized_text)
    item.is_a?(Hash) && item["title"].to_s.strip.present? &&
      normalized_text.include?(item["quote"].to_s.gsub(/\s+/, " ").strip.presence || "\u0000") &&
      (Date.iso8601(item["due_on"].to_s) rescue false)
  end

  def post(system:, user:)
    req = Net::HTTP::Post.new(ENDPOINT, "content-type" => "application/json", "x-api-key" => ENV.fetch("ANTHROPIC_API_KEY"),
                                        "anthropic-version" => "2023-06-01")
    req.body = { model: ENV.fetch("LLM_MODEL"), max_tokens: 1024, system: system, messages: [ { role: "user", content: user } ] }.to_json
    res = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, read_timeout: 30) { |http| http.request(req) }
    raise "LLM request failed (#{res.code})" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).fetch("content").filter_map { |c| c["text"] }.join
  end
end
