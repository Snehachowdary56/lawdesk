class Matter < ApplicationRecord
  STATUSES = %w[open pending closed].freeze
  PRACTICE_AREAS = ["Family", "Real Estate", "Corporate", "Litigation", "Immigration", "Employment", "Wills and Estates"].freeze

  belongs_to :client
  has_many :documents, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :invoices, dependent: :restrict_with_error
  has_many :tasks, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :practice_area, inclusion: { in: PRACTICE_AREAS }
  validates :opened_on, presence: true

  scope :with_status, ->(status) { status.present? ? where(status: status) : all }

  def as_json(*)
    super(only: %i[id client_id title practice_area adverse_party status opened_on])
  end
end
