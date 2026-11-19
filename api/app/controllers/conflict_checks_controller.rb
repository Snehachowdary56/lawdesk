class ConflictChecksController < ApplicationController
  def show
    name = params[:name].to_s.strip
    return render(json: { error: "name is required" }, status: :bad_request) if name.empty?

    matches = ConflictCheck.call(name)
    render json: { name: name, conflict: matches.any?, matches: matches.map(&:to_h) }
  end
end
