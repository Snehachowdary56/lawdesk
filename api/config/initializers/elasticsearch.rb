# One shared Elasticsearch client for document search.
SEARCH_CLIENT = Elasticsearch::Client.new(
  url: ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200"),
  retry_on_failure: 2,
  request_timeout: 5
)
