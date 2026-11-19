require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  test "amount rounds half up to the cent" do
    entry = TimeEntry.new(minutes: 1, rate_cents: 30)   # 0.5 cent
    assert_equal 1, entry.amount_cents
  end

  test "rejects impossible time" do
    matter = make_matter
    [ 0, -5, 24 * 60 + 1 ].each do |minutes|
      entry = matter.time_entries.build(minutes: minutes, rate_cents: 100, worked_on: Date.current, description: "x")
      assert_not entry.valid?, "#{minutes} minutes should be invalid"
    end
  end
end
