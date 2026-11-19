require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    DocumentSearch.create_index!(force: true)
  end

  test "open a matter, log time, invoice it and read the summary" do
    post "/clients", params: { client: { name: "Lakeview Dental", email: "admin@lakeview.example" } }, as: :json
    assert_response :created
    client_id = response.parsed_body["id"]

    post "/matters", params: { matter: { client_id: client_id, title: "Employment contract review", practice_area: "Employment", opened_on: "2026-10-01" } }, as: :json
    assert_response :created
    matter_id = response.parsed_body["id"]

    post "/matters/#{matter_id}/time_entries", params: { time_entry: { worked_on: "2026-10-02", minutes: 45, rate_cents: 30_000, description: "Review contract" } }, as: :json
    assert_response :created
    assert_equal 22_500, response.parsed_body["amount_cents"]

    post "/matters/#{matter_id}/invoices", as: :json
    assert_response :created
    assert_equal 22_500, response.parsed_body["total_cents"]

    get "/matters/#{matter_id}"
    assert_equal({ "billed_cents" => 22_500, "unbilled_cents" => 0 }, response.parsed_body["summary"].slice("billed_cents", "unbilled_cents"))
  end

  test "validation errors come back as 422 with details" do
    post "/matters", params: { matter: { title: "", practice_area: "Astrology" } }, as: :json
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["details"].keys, "practice_area"
  end

  test "search and conflict check endpoints" do
    matter = make_matter(adverse_party: "Harbour Properties Ltd.")
    post "/matters/#{matter.id}/documents", params: { document: { title: "Statement of claim", body: "Claim for damages against the landlord." } }, as: :json
    assert_response :created
    DocumentSearch.refresh!

    get "/documents/search", params: { q: "damages" }
    assert_equal "Statement of claim", response.parsed_body["results"].first["title"]

    get "/conflict_check", params: { name: "Harbor Properties" }
    assert response.parsed_body["conflict"]
    assert_equal "adverse party", response.parsed_body["matches"].first["role"]

    get "/conflict_check"
    assert_response :bad_request
  end

  test "unknown matter is a 404 and nothing to bill is a 422" do
    get "/matters/999999"
    assert_response :not_found
    post "/matters/#{make_matter.id}/invoices", as: :json
    assert_response :unprocessable_entity
  end

  test "health check" do
    get "/up"
    assert_response :success
  end
end

class TimeEntrySyncTest < ActionDispatch::IntegrationTest
  test "a retried upload from the phone is not saved twice" do
    matter = make_matter
    body = { time_entry: { worked_on: "2027-01-10", minutes: 18, rate_cents: 25_000, description: "Review lease", client_ref: "m1a2b3-xyz" } }
    post "/matters/#{matter.id}/time_entries", params: body, as: :json
    assert_response :created
    post "/matters/#{matter.id}/time_entries", params: body, as: :json
    assert_response :ok
    assert_equal 1, matter.time_entries.count
    assert_equal 7_500, response.parsed_body["amount_cents"]
  end
end
