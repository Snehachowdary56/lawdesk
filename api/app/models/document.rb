class Document < ApplicationRecord
  belongs_to :matter
  has_many :tasks, dependent: :nullify

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true

  # Keep the Elasticsearch index in step with the database (only after the transaction commits).
  after_commit :index_for_search, on: %i[create update]
  after_commit :remove_from_search, on: :destroy

  def search_payload
    { matter_id: matter_id, client_id: matter.client_id, title: title, body: body, created_at: created_at.iso8601 }
  end

  private

  def index_for_search
    DocumentSearch.index(self)
  end

  def remove_from_search
    DocumentSearch.remove(id)
  end
end
