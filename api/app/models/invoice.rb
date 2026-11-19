class Invoice < ApplicationRecord
  belongs_to :matter, touch: true
  has_many :time_entries, dependent: :restrict_with_error

  validates :number, presence: true, uniqueness: true
  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }

  def as_json(*)
    super(only: %i[id matter_id number issued_on total_cents]).merge("entries" => time_entries.size)
  end
end
