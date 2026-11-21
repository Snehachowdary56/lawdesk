# Bug write-ups

Short write-ups of bugs found while building LawDesk: what happened, why, the fix, and what now stops it coming back.

## 1. Rails app failed to start: Redis cache store and connection_pool 3.x

**Symptom.** After a fresh `bundle install`, `bin/rails test` stopped before running a single test. Rails raised an error
while building the Redis cache store at boot (`config/application.rb` sets `config.cache_store = :redis_cache_store`).

**Cause.** The Gemfile did not pin `connection_pool`, so Bundler installed the newest major version, 3.x. Version 3 changed
the `ConnectionPool` constructor, and the Redis cache store in Rails 7.2 still calls it the 2.x way. Nothing in our code
had changed: a dependency upgrade on a fresh install broke start-up.

**Fix.** Pinned the gem to the version Rails 7.2 supports, with a comment explaining why
([commit a36683a](https://github.com/Snehachowdary56/lawdesk/commit/a36683a)):

```ruby
# connection_pool 3.x changed its constructor; Rails 7.2's Redis cache store expects 2.x
gem "connection_pool", "~> 2.4"
```

**Prevention.** CI boots the full app against real MySQL, Redis and Elasticsearch services on every push and runs the
35 Rails tests, so a dependency that breaks start-up fails the build instead of reaching a deploy. When upgrading Rails,
remove the pin and let CI confirm the newer pool works.

**Lesson.** A failure on a fresh install with no code change usually means an unpinned dependency moved; compare
`Gemfile.lock` with the last good run first.
