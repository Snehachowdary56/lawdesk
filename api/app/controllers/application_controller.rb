class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: "#{e.model || 'Record'} not found" }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "Validation failed", details: e.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  rescue_from ActionController::BadRequest do |e|
    render json: { error: e.message }, status: :bad_request
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end
end
