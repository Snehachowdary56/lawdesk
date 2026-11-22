# Weekly time report for one matter: billable and non-billable hours, billed and unbilled amounts per week.
# Weeks start on Monday. Every week in the range is listed, with zeros when no time was logged, so a chart
# or table built from it has no gaps.
class TimeReport
  MAX_DAYS = 366

  def initialize(matter, from:, to:)
    raise ArgumentError, "from must be on or before to" if from > to
    raise ArgumentError, "the range can be at most #{MAX_DAYS} days" if (to - from).to_i >= MAX_DAYS

    @matter = matter
    @from = from
    @to = to
  end

  def weeks
    @weeks ||= begin
      by_week = entries.group_by { |e| e.worked_on.beginning_of_week(:monday) }
      week_starts.map { |start| { "week_start" => start.iso8601 }.merge(sums(by_week.fetch(start, []))) }
    end
  end

  # Summed from the entries, not the rounded weekly hours, so rounding never adds up wrongly.
  def totals
    sums(entries)
  end

  private

  def entries
    @entries ||= @matter.time_entries.where(worked_on: @from..@to).to_a
  end

  def week_starts
    (@from.beginning_of_week(:monday)..@to).step(7).to_a
  end

  def sums(list)
    billable, other = list.partition(&:billable)
    {
      "billable_hours" => hours(billable),
      "non_billable_hours" => hours(other),
      "billed_cents" => billable.select(&:invoice_id).sum(&:amount_cents),
      "unbilled_cents" => billable.reject(&:invoice_id).sum(&:amount_cents)
    }
  end

  def hours(list)
    (list.sum(&:minutes) / 60.0).round(2)
  end
end
