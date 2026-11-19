class Client < ApplicationRecord
  has_many :matters, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 200 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
