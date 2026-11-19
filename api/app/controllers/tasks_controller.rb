class TasksController < ApplicationController
  # GET /matters/:matter_id/tasks
  def index
    matter = Matter.find(params[:matter_id])
    render json: matter.tasks.where(status: params.fetch(:status, "open")).order(:due_on)
  end

  # POST /documents/:id/deadlines  { base_date: "2027-01-08", mode: "rules" | "llm" }
  # Finds deadlines in a document and saves them as tasks (running it twice does not duplicate tasks).
  def extract
    document = Document.find(params[:id])
    base_date = params[:base_date].present? ? Date.iso8601(params[:base_date]) : document.created_at.to_date
    found, rejected = find_deadlines(document, base_date)
    tasks = found.map do |d|
      Task.create_with(matter: document.matter, evidence: d.evidence, source: d.source)
          .find_or_create_by!(document: document, due_on: d.due_on, title: d.title)
    end
    render json: { document_id: document.id, base_date: base_date, mode: found.first&.source || params.fetch(:mode, "rules"),
                   rejected_by_guardrails: rejected, tasks: tasks }, status: :created
  rescue Date::Error
    render json: { error: "base_date must be YYYY-MM-DD" }, status: :bad_request
  end

  private

  def find_deadlines(document, base_date)
    if params[:mode] == "llm"
      return render_unavailable unless LlmDeadlineExtractor.available?

      result = LlmDeadlineExtractor.new.call(document.body, base_date: base_date)
      [ result.deadlines, result.rejected ]
    else
      [ DeadlineExtractor.call(document.body, base_date: base_date), 0 ]
    end
  end

  def render_unavailable
    raise ActionController::BadRequest, "LLM mode needs ANTHROPIC_API_KEY and LLM_MODEL"
  end
end
