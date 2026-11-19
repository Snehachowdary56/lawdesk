class DocumentsController < ApplicationController
  def create
    matter = Matter.find(params[:matter_id])
    doc = matter.documents.create!(params.require(:document).permit(:title, :body))
    render json: doc.as_json(only: %i[id matter_id title]), status: :created
  end

  def search
    query = params[:q].to_s.strip
    return render(json: { error: "q is required" }, status: :bad_request) if query.empty?

    render json: { query: query, results: DocumentSearch.search(query, matter_id: params[:matter_id], size: params.fetch(:size, 10)) }
  end
end
