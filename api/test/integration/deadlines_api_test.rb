require "test_helper"

class DeadlinesApiTest < ActionDispatch::IntegrationTest
  test "turns a document's deadlines into tasks, without duplicates" do
    matter = make_matter(practice_area: "Litigation", title: "Smith v. Harbour Properties")
    doc = matter.documents.create!(title: "Statement of claim",
                                   body: "You must serve and file a Statement of Defence within 20 days of service. The trial is scheduled for June 7, 2027.")

    2.times { post "/documents/#{doc.id}/deadlines", params: { base_date: "2027-01-08" }, as: :json }
    assert_response :created
    assert_equal 2, Task.count

    get "/matters/#{matter.id}/tasks"
    assert_equal [ "2027-01-28", "2027-06-07" ], response.parsed_body.map { |t| t["due_on"] }
    assert_equal "rules", response.parsed_body.first["source"]
  end

  test "LLM mode explains itself when it is not configured" do
    doc = make_matter.documents.create!(title: "Notice", body: "Pay within 5 days of receipt.")
    post "/documents/#{doc.id}/deadlines", params: { mode: "llm" }, as: :json
    assert_response :bad_request
    assert_match "ANTHROPIC_API_KEY", response.parsed_body["error"]
  end
end
