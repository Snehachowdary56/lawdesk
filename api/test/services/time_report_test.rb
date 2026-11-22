require "test_helper"

# Written first (test-driven): these describe the weekly time report before it exists.
class TimeReportTest < ActiveSupport::TestCase
  # 1 Oct 2026 is a Thursday, so 1-14 Oct covers the weeks starting Mon 28 Sep, 5 Oct and 12 Oct.
  FROM = Date.new(2026, 10, 1)
  TO = Date.new(2026, 10, 14)

  def report(matter, from: FROM, to: TO)
    TimeReport.new(matter, from: from, to: to)
  end

  test "groups time by week starting Monday and splits billable from non-billable hours" do
    matter = make_matter
    log_time(matter, minutes: 90, worked_on: Date.new(2026, 10, 1))
    log_time(matter, minutes: 30, worked_on: Date.new(2026, 10, 2), billable: false)
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 6))

    weeks = report(matter).weeks
    assert_equal %w[2026-09-28 2026-10-05 2026-10-12], weeks.map { |w| w["week_start"] }
    assert_equal({ "billable_hours" => 1.5, "non_billable_hours" => 0.5 }, weeks[0].slice("billable_hours", "non_billable_hours"))
    assert_equal 1.0, weeks[1]["billable_hours"]
  end

  test "weeks with no time are listed with zeros, so there are no gaps" do
    matter = make_matter
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 1))

    empty = report(matter).weeks.last
    assert_equal({ "week_start" => "2026-10-12", "billable_hours" => 0.0, "non_billable_hours" => 0.0, "billed_cents" => 0, "unbilled_cents" => 0 }, empty)
  end

  test "time outside the date range is left out" do
    matter = make_matter
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 9, 30)) # same week as 1 Oct, but before the range
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 15))
    log_time(matter, minutes: 45, worked_on: Date.new(2026, 10, 14))

    assert_equal 0.75, report(matter).totals["billable_hours"]
  end

  test "billable time is split into billed and unbilled amounts" do
    matter = make_matter
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 1)) # $250.00
    InvoiceBuilder.call(matter)
    log_time(matter, minutes: 30, worked_on: Date.new(2026, 10, 2)) # $125.00, not invoiced yet

    week = report(matter.reload).weeks.first
    assert_equal [ 25_000, 12_500 ], week.values_at("billed_cents", "unbilled_cents")
  end

  test "totals add up the weeks" do
    matter = make_matter
    log_time(matter, minutes: 60, worked_on: Date.new(2026, 10, 1))
    log_time(matter, minutes: 120, worked_on: Date.new(2026, 10, 13))
    log_time(matter, minutes: 15, worked_on: Date.new(2026, 10, 7), billable: false)

    result = report(matter)
    assert_equal({ "billable_hours" => 3.0, "non_billable_hours" => 0.25, "billed_cents" => 0, "unbilled_cents" => 75_000 }, result.totals)
  end

  test "rejects a range that ends before it starts or is longer than a year" do
    matter = make_matter
    assert_raises(ArgumentError) { report(matter, from: TO, to: FROM) }
    assert_raises(ArgumentError) { report(matter, from: Date.new(2025, 1, 1), to: Date.new(2026, 6, 1)) }
  end
end
