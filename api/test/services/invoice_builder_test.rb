require "test_helper"

class InvoiceBuilderTest < ActiveSupport::TestCase
  test "bills unbilled billable time up to the date, with rounding to the cent" do
    matter = make_matter
    log_time(matter, minutes: 90)                                   # 1.5 h x $250 = $375.00
    log_time(matter, minutes: 7, rate_cents: 20_000)                # 7/60 x $200 = $23.33
    log_time(matter, minutes: 60, billable: false)                  # not billed
    later = log_time(matter, minutes: 30, worked_on: Date.new(2026, 11, 15))

    invoice = InvoiceBuilder.call(matter, through: Date.new(2026, 10, 31), issued_on: Date.new(2026, 11, 1))

    assert_equal 39_833, invoice.total_cents
    assert_equal "INV-202611-0001", invoice.number
    assert_equal 2, invoice.time_entries.count
    assert_nil later.reload.invoice_id
  end

  test "never bills the same time twice" do
    matter = make_matter
    log_time(matter, minutes: 60)
    assert InvoiceBuilder.call(matter)
    assert_nil InvoiceBuilder.call(matter)
    assert_equal 1, Invoice.count
  end

  test "numbers invoices in sequence each month" do
    matter = make_matter
    2.times do
      log_time(matter, minutes: 60)
      InvoiceBuilder.call(matter, issued_on: Date.new(2026, 12, 3))
    end
    assert_equal %w[INV-202612-0001 INV-202612-0002], Invoice.order(:id).pluck(:number)
  end

  test "invoiced time cannot be edited" do
    matter = make_matter
    entry = log_time(matter, minutes: 60)
    InvoiceBuilder.call(matter)
    entry.reload.minutes = 120
    assert_not entry.save
  end
end
