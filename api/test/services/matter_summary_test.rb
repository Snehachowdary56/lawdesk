require "test_helper"

class MatterSummaryTest < ActiveSupport::TestCase
  def sql_count(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  test "summary is computed once, then served from Redis" do
    matter = make_matter
    log_time(matter, minutes: 120)
    first = sql_count { MatterSummary.for(matter) }
    second = sql_count { MatterSummary.for(matter) }
    assert_operator first, :>, 0
    assert_equal 0, second
    assert_kind_of ActiveSupport::Cache::RedisCacheStore, Rails.cache
  end

  test "new time on the matter refreshes the summary" do
    matter = make_matter
    log_time(matter, minutes: 60)
    assert_equal 1.0, MatterSummary.for(matter.reload)["total_hours"]
    log_time(matter, minutes: 30)
    assert_equal 1.5, MatterSummary.for(matter.reload)["total_hours"]
  end

  test "billed and unbilled amounts" do
    matter = make_matter
    log_time(matter, minutes: 60)
    InvoiceBuilder.call(matter)
    log_time(matter, minutes: 30)
    summary = MatterSummary.for(matter.reload)
    assert_equal [ 25_000, 12_500, 1 ], summary.values_at("billed_cents", "unbilled_cents", "invoices")
  end
end
