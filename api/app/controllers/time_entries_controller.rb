class TimeEntriesController < ApplicationController
  FIELDS = %i[worked_on minutes rate_cents billable description client_ref].freeze

  # Idempotent: if the phone retries an entry the API already has (same client_ref), return it with 200.
  def create
    matter = Matter.find(params[:matter_id])
    attrs = params.require(:time_entry).permit(*FIELDS)
    existing = attrs[:client_ref].present? && matter.time_entries.find_by(client_ref: attrs[:client_ref])
    return render(json: payload(existing), status: :ok) if existing

    entry = matter.time_entries.create!(attrs)
    render json: payload(entry), status: :created
  rescue ActiveRecord::RecordNotUnique
    render json: payload(TimeEntry.find_by!(client_ref: attrs[:client_ref])), status: :ok
  end

  private

  def payload(entry)
    entry.as_json(only: %i[id matter_id worked_on minutes rate_cents billable description client_ref]).merge("amount_cents" => entry.amount_cents)
  end
end
