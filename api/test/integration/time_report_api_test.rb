require "test_helper"

# Written first (test-driven): the JSON endpoint for the weekly time report.
class TimeReportApiTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    DocumentSearch.create_index!(force: true)
  end

  test "returns weekly rows and totals for a date range" do
    matter = make_matter
    log_time(matter, minutes: 90, worked_on: Date.new(2026, 10, 1))
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 6), billable: false)

    get "/matters/#{matter.id}/time_report", params: { from: "2026-10-01", to: "2026-10-14" }
    assert_response :ok
    body = response.parsed_body
    assert_equal({ "from" => "2026-10-01", "to" => "2026-10-14" }, body.slice("from", "to"))
    assert_equal %w[2026-09-28 2026-10-05 2026-10-12], body["weeks"].map { |w| w["week_start"] }
    assert_equal({ "billable_hours" => 1.5, "non_billable_hours" => 1.0, "billed_cents" => 0, "unbilled_cents" => 37_500 }, body["totals"])
  end

  test "bad or missing dates are a 400 with a clear message" do
    matter = make_matter
    get "/matters/#{matter.id}/time_report", params: { from: "2026-10-14", to: "2026-10-01" }
    assert_response :bad_request
    assert_match "from must be on or before to", response.parsed_body["error"]

    get "/matters/#{matter.id}/time_report", params: { from: "not-a-date", to: "2026-10-01" }
    assert_response :bad_request

    get "/matters/#{matter.id}/time_report", params: { to: "2026-10-01" }
    assert_response :bad_request
  end

  test "unknown matter is a 404" do
    get "/matters/999999/time_report", params: { from: "2026-10-01", to: "2026-10-14" }
    assert_response :not_found
  end
end
