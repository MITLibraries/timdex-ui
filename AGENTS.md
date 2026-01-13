# Guidance for AI coding agents working on timdex-ui

This file highlights the important, discoverable conventions and workflows an AI coding agent needs to be productive in this Rails app.

- **Big picture:** TIMDEX UI is a Rails 7 app that orchestrates searches across two backends: TIMDEX (GraphQL) and Primo (legacy API). Core request flow is implemented in `app/controllers/search_controller.rb` which: validates params, builds an enhanced query (`Enhancer` -> `QueryBuilder`), then routes to Primo or Timdex fetchers (or both for the `all` tab). Results are normalized by `NormalizePrimoResults` / `NormalizeTimdexResults` and analyzed by `Analyzer`.

- **GraphQL integration:** GraphQL queries live on the Ruby side using `graphql-client` and `TimdexBase::Client`. See `app/models/timdex_search.rb` for the queries (`BaseQuery`, `GeoboxQuery`, `GeodistanceQuery`, `AllQuery`). The canonical schema is stored at `config/schema/schema.json`. Update schema via the Rails console:

  ```ruby
  GraphQL::Client.dump_schema(TimdexBase::HTTP, 'config/schema/schema.json')
  ```

- **Caching & query keys:** `SearchController#query_timdex` uses `Rails.cache` and generates stable cache keys with `generate_cache_key` (MD5 of a sorted query hash). When changing query shape, update cache key logic or clear cache accordingly.

- **Feature flags & environment:** Feature toggles are read with `Feature.enabled?(:name)` via the `Feature` class (see `app/models/feature.rb`). This replaces the older flipflop gem-based approach with a simpler, stateless environment variable system. Valid flags are:

  | Flag | Purpose |
  |------|----------|
  | `FEATURE_GEODATA` | Enable geospatial search (bounding box and radius-based queries); defaults to false |
  | `FEATURE_BOOLEAN_PICKER` | Allow users to choose AND/OR boolean logic in searches |
  | `FEATURE_SIMULATE_SEARCH_LATENCY` | Add 1s minimum delay to search results for testing UX behavior |
  | `FEATURE_TAB_PRIMO_ALL` | Display combined Primo (CDI + Alma) results tab |
  | `FEATURE_TAB_TIMDEX_ALL` | Display combined TIMDEX results tab |
  | `FEATURE_TAB_TIMDEX_ALMA` | Display Alma-only TIMDEX results tab |
  | `FEATURE_RECORD_LINK` | Show "View full record" link in search results |

  Essential ENV vars for core functionality: `TIMDEX_GRAPHQL`, `PRIMO_API_URL`, `PRIMO_API_KEY`, `RESULTS_PER_PAGE`, `TIMDEX_INDEX`, `TIMDEX_SOURCES`. Filter customization: `FILTER_*` (e.g., `FILTER_LANGUAGE`, `FILTER_CONTENT_TYPE`) and `ACTIVE_FILTERS` (comma-separated list controlling visibility/order of filters; note that filter aggregation keys in the schema use `*Filter` suffix, e.g., `languageFilter`, `contentTypeFilter`). Tests rely on `.env.test` values for VCR cassette generation and use `ClimateControl` gem to mock feature flags.

- **Parallel fetching & multi-source pagination:** The `all` tab uses `MergedSearchService` (with `MergedSearchPaginator`) to fetch Primo and Timdex concurrently via `Thread.new`, then intelligently merges paginated results. Primo has a practical offset limit (~960 records); when this limit is reached, the UI shows a `show_continuation` flag to indicate search is exhausted. Merged totals are cached for 12 hours. Be careful when refactoring to preserve thread-safety, caching semantics, and offset limit handling.

- **JS stack & conventions:** Rails importmap is in use (`importmap-rails`). JavaScript entry is `app/javascript/application.js`. Stimulus controllers live in `app/javascript/controllers` and are imported by `importmap` via `config/importmap.rb`. Key controllers include `content_loader_controller.js` (dynamic content loading) and tab management via `source_tabs.js` (which handles geospatial UI state). Prefer small, focused changes to Stimulus controllers rather than heavy bundler-based rewrites.

- **Geospatial search pattern:** When `FEATURE_GEODATA` is enabled, `SearchController` supports two additional query types beyond keyword search: **geobox** (bounding box with min/max latitude/longitude) and **geodistance** (radius search with distance, latitude, longitude). These are implemented via `GeoboxQuery` and `GeodistanceQuery` in `TimdexSearch` and routed to a dedicated `results_geo` view. Use case: GEODATA (geographic discovery tool) app uses this for location-based discovery; other apps can leverage the same pattern for their own needs. Input validation guards these features: `validate_geobox_*` and `validate_geodistance_*` methods check coordinate ranges and required params before querying. When changing geospatial UX or params, update these validations and corresponding flash messages.

- **Errors & UX flows:** Search errors are extracted in `SearchController` (`extract_errors`) and rendered to the UI. When implementing new search types or filters, ensure error handling covers both success and failure cases, and update flash messages for clarity.

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

- **Testing geospatial features:** Geospatial tests follow the same VCR pattern. When writing tests for geobox or geodistance queries:

  - Use `ClimateControl.modify(FEATURE_GEODATA: 'true')` to enable the feature flag in test blocks (see test helper for patterns).
  - Create VCR cassettes named with `geobox_*` or `geodistance_*` suffixes to keep them organized separately from standard search cassettes.
  - Test both validation (e.g., missing coordinates, invalid ranges) and successful query paths (verify aggregations include `places` for geobox).
  - Disable `FEATURE_GEODATA` by default in `.env.test` and only enable in specific test cases to avoid unintended side effects.

- **Common pitfalls to avoid:**

  - Don’t assume GraphQL responses are serializable — code converts `GraphQL::Client::Response` to hashes (`raw.data.to_h`, `raw.errors.details.to_h`). Keep that conversion when changing callers.
  - When adding or reordering filters, note `ACTIVE_FILTERS` impacts `extract_filters`/`reorder_filters` flow. The schema uses `*Filter` suffix for aggregation keys (e.g., `contentTypeFilter`, `languageFilter`); ensure ENV variable filter name maps correctly to schema aggregation name.
  - Primo has offset limits; `Analyzer::PRIMO_MAX_OFFSET` (960) is used by `MergedSearchPaginator` to prevent invalid requests and to enable `show_continuation` behavior.
  - When modifying `SearchController` routing, ensure geospatial (`geobox` / `geodistance`) branches are only reached when `FEATURE_GEODATA` is enabled, and standard keyword/filter search still works when geospatial is disabled.

- **Developer workflows / commands:**

  - Run tests: `bin/rails test` (or via your devcontainer). The project expects high test coverage. Use `SPEC_REPORTER` for verbose test output.
  - Update GraphQL schema (see example above).
  - Use devcontainers if available (see README) to match developer environment.

- **Where to look for more context:**
  - `README.md` — env vars, VCR and schema notes
  - `app/controllers/search_controller.rb` — primary request orchestration, including geospatial routing and error handling
  - `app/models/timdex_search.rb` and `app/models/timdex_base.rb` — GraphQL client and all four query types (`BaseQuery`, `AllQuery`, `GeoboxQuery`, `GeodistanceQuery`)
  - `app/models/merged_search_service.rb` and `app/models/merged_search_paginator.rb` — multi-source result merging and intelligent pagination
  - `app/models/feature.rb` — feature flag class and implementation
  - `app/models/primo_search.rb` — Primo client behavior
  - `app/javascript/*` and `config/importmap.rb` — JS/Stimulus usage, including geospatial UI state in `source_tabs.js`
