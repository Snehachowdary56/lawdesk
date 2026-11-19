class Task < ApplicationRecord
  belongs_to :matter
  belongs_to :document, optional: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :due_on, presence: true
  validates :source, inclusion: { in: %w[manual rules llm] }
  validates :status, inclusion: { in: %w[open done] }

  def as_json(*)
    super(only: %i[id matter_id document_id title due_on source evidence status])
  end
end
