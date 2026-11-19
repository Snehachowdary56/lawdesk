class MattersController < ApplicationController
  def index
    matters = Matter.with_status(params[:status]).order(opened_on: :desc).limit(100)
    render json: matters
  end

  def show
    matter = Matter.find(params[:id])
    render json: matter.as_json.merge("summary" => MatterSummary.for(matter))
  end

  def create
    matter = Matter.create!(params.require(:matter).permit(:client_id, :title, :practice_area, :adverse_party, :status, :opened_on))
    render json: matter, status: :created
  end
end
