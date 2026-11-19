ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module TestData
  def make_client(name = "Northside Bakery Inc.")
    Client.create!(name: name, email: "office@example.com")
  end

  def make_matter(client: make_client, **attrs)
    Matter.create!({ client: client, title: "Lease dispute", practice_area: "Real Estate", opened_on: Date.new(2026, 9, 1) }.merge(attrs))
  end

  def log_time(matter, minutes:, rate_cents: 25_000, billable: true, worked_on: Date.new(2026, 10, 1))
    matter.time_entries.create!(minutes: minutes, rate_cents: rate_cents, billable: billable, worked_on: worked_on, description: "Work")
  end
end

class ActiveSupport::TestCase
  include TestData

  setup do
    Rails.cache.clear
    DocumentSearch.create_index!(force: true)
  end
end

class ActionDispatch::IntegrationTest
  include TestData
end
