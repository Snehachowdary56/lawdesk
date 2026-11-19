# Lets the AngularJS dashboard (served from another port or domain) call the API from the browser.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080").split(","))
    resource "*", headers: :any, methods: %i[get post options]
  end
end
