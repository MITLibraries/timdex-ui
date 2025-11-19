# Guidance for AI coding agents working on timdex-ui

This file highlights the important, discoverable conventions and workflows an AI coding agent needs to be productive in this Rails app.

- **Big picture:** TIMDEX UI is a Rails 7 app that orchestrates searches across two backends: TIMDEX (GraphQL) and Primo (legacy API). Core request flow is implemented in `app/controllers/search_controller.rb` which: validates params, builds an enhanced query (`Enhancer` -> `QueryBuilder`), then routes to Primo or Timdex fetchers (or both for the `all` tab). Results are normalized by `NormalizePrimoResults` / `NormalizeTimdexResults` and analyzed by `Analyzer`.

- **GraphQL integration:** GraphQL queries live on the Ruby side using `graphql-client` and `TimdexBase::Client`. See `app/models/timdex_search.rb` for the queries (`BaseQuery`, `GeoboxQuery`, `GeodistanceQuery`, `AllQuery`). The canonical schema is stored at `config/schema/schema.json`. Update schema via the Rails console:

  ```ruby
  GraphQL::Client.dump_schema(TimdexBase::HTTP, 'config/schema/schema.json')
  ```

- **Caching & query keys:** `SearchController#query_timdex` uses `Rails.cache` and generates stable cache keys with `generate_cache_key` (MD5 of a sorted query hash). When changing query shape, update cache key logic or clear cache accordingly.

- **Feature flags & environment:** Feature toggles are read with `Feature.enabled?(:name)` and many behaviours are controlled by ENV variables (see README). Important env vars: `TIMDEX_GRAPHQL`, `PRIMO_API_URL`, `PRIMO_API_KEY`, `FEATURE_GEODATA`, `FEATURE_SIMULATE_SEARCH_LATENCY`, `FEATURE_TAB_TIMDEX`, and many `FILTER_*`/`ACTIVE_FILTERS` values. Tests rely on `.env.test` values for VCR cassette generation.

- **Parallel fetching pattern:** The `all` tab uses `Thread.new` to fetch Primo and Timdex concurrently and then zips results. Be careful when refactoring to preserve thread-safety and caching semantics.

- **JS stack & conventions:** Rails importmap is in use (`importmap-rails`). JavaScript entry is `app/javascript/application.js`. Stimulus controllers live in `app/javascript/controllers` and are imported by `importmap` via `config/importmap.rb`. Prefer small, focused changes to Stimulus controllers rather than heavy bundler-based rewrites.

- **Errors & UX flows:** Search errors are extracted in `SearchController` (`extract_errors`) and rendered to the UI. Geospatial features are guarded by feature flags and many validations (see `validate_geobox_*` and `validate_geodistance_*`). When changing UX or params, update these validations and corresponding flash messages.

- **Naming patterns and responsibilities:** Look for classes with these roles and names:

  - Query composition: `Enhancer`, `QueryBuilder`
  - API clients: `TimdexBase`, `TimdexSearch`, `PrimoSearch`
  - Normalizers: `NormalizeTimdexResults`, `NormalizePrimoResults`
  - Analysis / pagination: `Analyzer`
  - Controllers orchestrate flow: `app/controllers/search_controller.rb`, `basic_search_controller.rb`, `record_controller.rb`.

- **Testing & VCR:** Tests use `minitest`, `vcr`, and `webmock`. When creating or updating VCR cassettes:

  - Update `.env.test` with fake `TIMDEX_GRAPHQL` / `TIMDEX_HOST` (as documented in README) before recording.
  - Commit `.env.test` (it should not contain real credentials).
  - Run the test that exercises the request to generate new cassettes.

- **Common pitfalls to avoid:**

  - Don’t assume GraphQL responses are serializable — code converts `GraphQL::Client::Response` to hashes (`raw.data.to_h`, `raw.errors.details.to_h`). Keep that conversion when changing callers.
  - When adding or reordering filters, note `ACTIVE_FILTERS` impacts `extract_filters`/`reorder_filters` flow (aggregation key renaming to `*Filter`).
  - Primo has offset limits; `Analyzer::PRIMO_MAX_OFFSET` is used to prevent invalid requests and to enable `show_continuation` behavior.

- **Developer workflows / commands:**

  - Run tests: `bin/rails test` (or via your devcontainer). The project expects high test coverage. Use `SPEC_REPORTER` for verbose test output.
  - Update GraphQL schema (see example above).
  - Use devcontainers if available (see README) to match developer environment.

- **Where to look for more context:**
  - `README.md` — env vars, VCR and schema notes
  - `app/controllers/search_controller.rb` — primary request orchestration
  - `app/models/timdex_search.rb` and `app/models/timdex_base.rb` — GraphQL client and queries
  - `app/models/primo_search.rb` — Primo client behavior
  - `app/javascript/*` and `config/importmap.rb` — JS/Stimulus usage
