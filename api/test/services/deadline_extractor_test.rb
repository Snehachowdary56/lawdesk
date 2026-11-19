require "test_helper"

class DeadlineExtractorTest < ActiveSupport::TestCase
  CLAIM = <<~TEXT.freeze
    This Statement of Claim is dated January 5, 2027. If you wish to defend this proceeding, you must serve and file a
    Statement of Defence within 20 days of service of this Statement of Claim. The plaintiff must deliver an affidavit of
    documents no later than March 15, 2027. The settlement conference is scheduled for 4 February 2027. The tenant shall
    pay the arrears within thirty (30) business days after receipt of this notice; failing that, the landlord may apply.
    Payment is due by 2027-04-30.
  TEXT

  def found = DeadlineExtractor.call(CLAIM, base_date: Date.new(2027, 1, 8))

  test "finds explicit and relative deadlines in date order" do
    assert_equal [ Date.new(2027, 1, 28), Date.new(2027, 2, 4), Date.new(2027, 2, 19), Date.new(2027, 3, 15), Date.new(2027, 4, 30) ],
                 found.map(&:due_on)
  end

  test "ignores dates that are not deadlines" do
    assert_not_includes found.map(&:due_on), Date.new(2027, 1, 5)
  end

  test "titles start with the action" do
    titles = found.map(&:title)
    assert_includes titles, "Serve and file a Statement of Defence"
    assert_includes titles, "Deliver an affidavit of documents"
  end

  test "business days skip weekends" do
    assert_equal Date.new(2027, 1, 11), DeadlineExtractor.business_days_after(Date.new(2027, 1, 8), 1)   # Friday -> Monday
  end

  test "number words and every date format" do
    text = "Reply within fifteen days of receipt. Sign and return the form on or before 3 Mar 2027."
    assert_equal [ Date.new(2027, 1, 16), Date.new(2027, 3, 3) ], DeadlineExtractor.call(text, base_date: Date.new(2027, 1, 1)).map(&:due_on)
  end

  test "keeps the sentence as evidence" do
    assert(found.all? { |d| CLAIM.gsub(/\s+/, " ").include?(d.evidence) })
  end
end

class LlmDeadlineExtractorTest < ActiveSupport::TestCase
  TEXT = "You must serve a reply within 10 days of service. The hearing is set for March 2, 2027."

  def run_with(reply)
    LlmDeadlineExtractor.new(transport: ->(**) { reply }).call(TEXT, base_date: Date.new(2027, 1, 4))
  end

  test "accepts deadlines that quote the document" do
    reply = { deadlines: [ { due_on: "2027-01-14", title: "Serve a reply", quote: "You must serve a reply within 10 days of service." } ] }.to_json
    result = run_with("Here you go: #{reply}")
    assert_equal [ [ Date.new(2027, 1, 14), "llm" ] ], result.deadlines.map { |d| [ d.due_on, d.source ] }
    assert_equal 0, result.rejected
  end

  test "guardrails drop invented quotes and impossible dates" do
    reply = { deadlines: [
      { due_on: "2027-02-01", title: "Pay costs", quote: "The defendant must pay costs by February 1, 2027." },   # not in the document
      { due_on: "2027-02-30", title: "Hearing", quote: "The hearing is set for March 2, 2027." },                 # not a real date
      { due_on: "2027-03-02", title: "Attend hearing", quote: "The hearing is set for March 2, 2027." }
    ] }.to_json
    result = run_with(reply)
    assert_equal [ "Attend hearing" ], result.deadlines.map(&:title)
    assert_equal 2, result.rejected
  end

  test "a reply that is not JSON is rejected, not crashed on" do
    result = run_with("Sorry, I cannot help with that.")
    assert_empty result.deadlines
  end
end
