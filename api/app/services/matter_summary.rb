# Totals for a matter (hours, billed and unbilled amounts, documents). Cached in Redis under the matter's
# cache key, which changes whenever its time entries or invoices change (touch: true), so it never goes stale.
class MatterSummary
  def self.for(matter)
    Rails.cache.fetch([ "matter-summary", matter.cache_key_with_version ], expires_in: 12.hours) { compute(matter) }
  end

  def self.compute(matter)
    entries = matter.time_entries.to_a
    billable = entries.select(&:billable)
    {
      "total_hours" => (entries.sum(&:minutes) / 60.0).round(2),
      "billable_hours" => (billable.sum(&:minutes) / 60.0).round(2),
      "unbilled_cents" => billable.reject(&:invoice_id).sum(&:amount_cents),
      "billed_cents" => matter.invoices.sum(:total_cents),
      "invoices" => matter.invoices.count,
      "documents" => matter.documents.count
    }
  end
end
