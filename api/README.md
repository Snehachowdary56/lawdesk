# LawDesk API (Ruby on Rails)

A small legal practice management API in **Ruby on Rails**: clients, matters (legal cases), billable time,
invoices, full-text search over case documents, and a conflict-of-interest check. Built to learn the stack
used by legal SaaS products: **Rails, MySQL, Redis and Elasticsearch**.

## Features

| Feature | How it works |
|---|---|
| Clients and matters | Rails models on **MySQL** with validations, foreign keys and indexes |
| Time and billing | Time entries in cents; an invoice bills all unbilled, billable time up to a date. It runs in one transaction and **locks the rows** (`SELECT ... FOR UPDATE`), so the same time can never be billed twice. Invoiced time cannot be edited. |
| Matter summary | Hours, billed and unbilled amounts, cached in **Redis** under the matter's cache key; new time or invoices `touch` the matter, so the cache refreshes itself |
| Document search | **Elasticsearch** with the English analyzer (finds "terminate" for "termination"), fuzzy matching for typos, title boosting, highlighted snippets and a per-matter filter. The index is updated after each database commit. |
| Deadline extraction | Reads a document and turns its deadlines into tasks: explicit dates next to a deadline cue ("no later than March 15, 2027") and relative periods ("within 20 days of service", business days skip weekends). Dates that are not deadlines ("dated January 5") are ignored. Optional **LLM mode** (Anthropic API) with guardrails: the reply must be valid JSON, every deadline must quote a sentence that is really in the document, and every date must be real; anything else is dropped and counted. Running it twice does not duplicate tasks. |
| Offline sync support | Time entries accept a `client_ref`; if the mobile app retries an upload the API already has, it returns the existing entry (200) instead of saving it twice |
| Conflict check | Before taking a new client, finds the name among existing clients and opposing parties. Normalises names (case, punctuation, "Inc", "Ltd", "LLP"...) and scores them with **Levenshtein edit distance** (dynamic programming, two-row memory) and **word overlap**; flags anything at 80% similarity or more. Catches "ACME Corp." vs "Acme Corporation" and typos like "Jonh Smith". |

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/up` | Health check |
| GET, POST | `/clients` | List or add clients |
| GET | `/matters?status=open` | List matters |
| GET | `/matters/:id` | Matter with its cached summary |
| POST | `/matters` | Open a matter |
| POST | `/matters/:id/time_entries` | Log time |
| POST | `/matters/:id/invoices?through=YYYY-MM-DD` | Invoice unbilled time (422 if nothing to bill) |
| POST | `/matters/:id/documents` | Add a document (indexed for search) |
| GET | `/documents/search?q=...&matter_id=...` | Search documents |
| POST | `/documents/:id/deadlines` | Extract deadlines into tasks (`base_date`, `mode=rules` or `llm`) |
| GET | `/matters/:id/tasks` | Open tasks by due date |
| GET | `/conflict_check?name=...` | Conflict-of-interest check |

Errors are JSON: 400 for missing parameters, 404 for unknown records, 422 with field details for validation errors.

## Tests

Minitest model, service and API tests run in GitHub Actions against **real MySQL 8, Redis 7 and
Elasticsearch 8** on every push. They cover billing totals and rounding, double-billing protection, invoice
numbering, cache hits and refreshes (counting SQL queries), search ranking, typos and deletions, conflict
matching (including no false match), deadline extraction, LLM guardrails (with a fake model), idempotent sync, and API status codes.

## Run it

Needs Ruby 3.3, MySQL, Redis and Elasticsearch (for example with Docker):

```
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:8.0
docker run -d -p 6379:6379 redis:7
docker run -d -p 9200:9200 -e discovery.type=single-node -e xpack.security.enabled=false docker.elastic.co/elasticsearch/elasticsearch:8.15.3
cd api
bundle install
set DB_PASSWORD=root
bin/rails db:create db:migrate
bin/rails test
bin/rails server
```

(On macOS or Linux use `export DB_PASSWORD=root`.)

## Tech

Ruby on Rails 7.2 (API mode) · MySQL · Redis · Elasticsearch · Minitest · GitHub Actions
