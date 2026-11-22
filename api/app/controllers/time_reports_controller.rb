class TimeReportsController < ApplicationController
  # GET /matters/:matter_id/time_report?from=YYYY-MM-DD&to=YYYY-MM-DD
  def show
    matter = Matter.find(params[:matter_id])
    from = date_param(:from)
    to = date_param(:to)
    report = TimeReport.new(matter, from: from, to: to)
    render json: { "matter_id" => matter.id, "from" => from.iso8601, "to" => to.iso8601, "weeks" => report.weeks, "totals" => report.totals }
  rescue ArgumentError => e
    raise ActionController::BadRequest, e.message
  end

  private

  def date_param(name)
    Date.iso8601(params.require(name))
  rescue Date::Error
    raise ActionController::BadRequest, "#{name} must be a date like 2026-10-01"
  end
end
