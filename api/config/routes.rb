Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :clients, only: %i[index create]
  resources :matters, only: %i[index show create] do
    resources :documents, only: %i[create]
    resources :time_entries, only: %i[create]
    resources :invoices, only: %i[create]
    resources :tasks, only: %i[index]
    resource :time_report, only: %i[show]
  end
  get "documents/search" => "documents#search"
  post "documents/:id/deadlines" => "tasks#extract"
  get "conflict_check" => "conflict_checks#show"
end
