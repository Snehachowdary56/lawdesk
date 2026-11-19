class TimeEntry < ApplicationRecord
  # touch: a new entry changes the matter's cache key, so its cached summary is rebuilt
  belongs_to :matter, touch: true
  belongs_to :invoice, optional: true

  validates :worked_on, :description, presence: true
  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 * 60 }
  validates :rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :cannot_change_once_invoiced, on: :update

  scope :unbilled, -> { where(billable: true, invoice_id: nil) }

  # Money in cents: minutes x hourly rate / 60, rounded half up to the cent.
  def amount_cents
    (minutes * rate_cents + 30) / 60
  end

  private

  def cannot_change_once_invoiced
    return unless invoice_id_was.present? && (will_save_change_to_minutes? || will_save_change_to_rate_cents?)

    errors.add(:base, "cannot change time that has already been invoiced")
  end
end
