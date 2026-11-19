class InvoicesController < ApplicationController
  def create
    matter = Matter.find(params[:matter_id])
    through = params[:through].present? ? Date.parse(params[:through]) : Date.current
    invoice = InvoiceBuilder.call(matter, through: through)
    return render(json: { error: "Nothing to bill" }, status: :unprocessable_entity) unless invoice

    render json: invoice, status: :created
  rescue Date::Error
    render json: { error: "through must be a date (YYYY-MM-DD)" }, status: :bad_request
  end
end
