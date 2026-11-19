class ClientsController < ApplicationController
  def index
    render json: Client.order(:name).limit(100).as_json(only: %i[id name email])
  end

  def create
    client = Client.create!(params.require(:client).permit(:name, :email))
    render json: client.as_json(only: %i[id name email]), status: :created
  end
end
