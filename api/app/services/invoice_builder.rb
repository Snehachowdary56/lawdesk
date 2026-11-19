# Bills all unbilled, billable time on a matter up to a date. Runs in one transaction and locks the rows,
# so two people pressing "Create invoice" at once cannot bill the same time twice.
class InvoiceBuilder
  def self.call(matter, through: Date.current, issued_on: Date.current)
    Invoice.transaction do
      entries = matter.time_entries.unbilled.where(worked_on: ..through).order(:worked_on, :id).lock.to_a
      next nil if entries.empty?

      invoice = matter.invoices.create!(
        number: next_number(issued_on),
        issued_on: issued_on,
        total_cents: entries.sum(&:amount_cents)
      )
      TimeEntry.where(id: entries.map(&:id)).update_all(invoice_id: invoice.id, updated_at: Time.current)
      invoice
    end
  end

  def self.next_number(date)
    prefix = "INV-#{date.strftime('%Y%m')}-"
    last = Invoice.where("number LIKE ?", "#{prefix}%").order(:number).last
    seq = last ? last.number.delete_prefix(prefix).to_i + 1 : 1
    format("%s%04d", prefix, seq)
  end
end
