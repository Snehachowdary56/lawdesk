# Full-text search over case documents with Elasticsearch: relevance ranking, fuzzy matching for typos,
# highlighted snippets, and an optional filter to one matter.
class DocumentSearch
  INDEX = "documents_#{Rails.env}".freeze
  MAPPINGS = {
    properties: {
      matter_id: { type: "integer" },
      client_id: { type: "integer" },
      title: { type: "text", analyzer: "english" },
      body: { type: "text", analyzer: "english" },
      created_at: { type: "date" }
    }
  }.freeze

  def self.client = SEARCH_CLIENT

  def self.create_index!(force: false)
    client.indices.delete(index: INDEX) if force && client.indices.exists(index: INDEX)
    client.indices.create(index: INDEX, body: { mappings: MAPPINGS }) unless client.indices.exists(index: INDEX)
  end

  def self.index(document)
    client.index(index: INDEX, id: document.id, body: document.search_payload)
  end

  def self.remove(id)
    client.delete(index: INDEX, id: id)
  rescue Elastic::Transport::Transport::Errors::NotFound
    nil
  end

  def self.refresh! = client.indices.refresh(index: INDEX)

  def self.search(query, matter_id: nil, size: 10)
    must = [ { multi_match: { query: query, fields: %w[title^3 body], fuzziness: "AUTO" } } ]
    filter = matter_id.present? ? [ { term: { matter_id: matter_id.to_i } } ] : []
    response = client.search(index: INDEX, body: {
      size: size.to_i.clamp(1, 50),
      query: { bool: { must: must, filter: filter } },
      highlight: { fields: { body: { fragment_size: 120, number_of_fragments: 1 } } }
    })
    response["hits"]["hits"].map do |hit|
      {
        id: hit["_id"].to_i,
        matter_id: hit["_source"]["matter_id"],
        title: hit["_source"]["title"],
        score: hit["_score"].round(3),
        snippet: hit.dig("highlight", "body", 0)
      }
    end
  end
end
