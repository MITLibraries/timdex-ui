# 3. Cache normalized search results

Date: 2026-09-04

## Status

Accepted

## Context

TIMDEX UI fetches search results from both Primo and TIMDEX. These provider responses are larger than the normalized
result hashes the application uses to render search results.

`SearchController#query_timdex` currently caches raw TIMDEX GraphQL response hashes after converting them from
`GraphQL::Client::Response` objects. `SearchController#query_primo` currently caches raw Primo API responses. In both
cases, `SearchController#fetch_timdex_data` and `SearchController#fetch_primo_data` normalize after cache retrieval, so
raw cache hits avoid external provider calls but still rerun normalization.

The all-tab load-more path has an additional cache layer in `MergedSearchService#fetch_load_more`. That state cache
stores normalized `primo_results` and `timdex_results`, along with ordered result keys, hit counts, exhaustion flags,
and errors. However, the all-tab service is populated by controller fetchers that currently call the raw single-source
caches. A single all-tab request can therefore leave both raw source cache entries and normalized all-tab state entries
in Redis.

This creates avoidable duplication and repeated normalization work. It also means the cache strategy differs by path:
single-source Primo and TIMDEX searches cache provider-shaped data, while all-tab load-more caches application-shaped
data.

## Decision

We will cache normalized search result payloads for single-source Primo and TIMDEX result requests instead of caching
raw provider responses.

For these requests, cache lookup will happen before any external Primo or TIMDEX API call and before any normalizer is
instantiated. On cache hit, the application will return the cached normalized payload directly. Cache hits must not call
Primo, TIMDEX, `NormalizePrimoResults`, or `NormalizeTimdexResults`.

Single-source Primo and TIMDEX result requests will use this flow:

```text
Single-source search request
    │
    ▼
Build source-specific cache key
    │
    ▼
Check normalized search result cache
    │
    ├── Cache hit
    │       │
    │       ├── Read normalized payload
    │       │       └── includes results, hits, errors, and continuation metadata
    │       │
    │       └── Build request-specific pagination and view data
    │               └── no Primo/TIMDEX API call and no normalization
    │
    └── Cache miss
        │
        ├── Call Primo or TIMDEX
        │
        ├── Normalize provider response once
        │
        ├── Write normalized payload to cache
        │       └── use explicit cache schema versioning or namespacing
        │
        └── Build request-specific pagination and view data
    │
    ▼
Render results
```

On cache miss, the application will call the external provider, normalize the response once, write the normalized
payload to cache, and return it. Cached payloads must include enough metadata to preserve current behavior, including
normalized `results`, `hits`, `errors`, and Primo `show_continuation` information where applicable.

We will use explicit cache schema versioning or namespacing so existing raw cached values are not read as normalized
payloads. We will preserve the current query-, tab-, offset-, and per-page-sensitive cache key behavior unless
implementation work identifies a specific reason to change it.

The all-tab load-more cache will remain application-shaped. This decision brings the single-source Primo and TIMDEX
cache strategy into alignment with that path and avoids storing raw source payloads for records that are already stored
in normalized form.

We will accept that all-tab load-more requests may store normalized source results twice: once in the source result
cache and once in the all-tab state cache. The all-tab state is not just a copy of source records. It also stores the
reranked result pool, stable display order, hit counts, source exhaustion flags, and errors needed to preserve the
load-more experience across requests.

All-tab load-more result requests will use this flow:

```text
All-tab load-more request
    │
    ▼
Build all-tab state cache key
    │
    ▼
Check reranked all-tab state cache
    │
    ├── Enough cached state exists
    │       │
    │       ├── Read reranked all-tab state
    │       │       └── includes normalized source results, ordered keys, hits, exhaustion flags, and errors
    │       │
    │       └── Return requested stable display slice
    │               └── no Primo/TIMDEX API call and no normalization
    │
    └── More source candidates needed
        │
        ├── Fetch next Primo and/or TIMDEX source chunk
        │       │
        │       ├── Check single source normalized source result cache (see above diagram)
        │       │       ├── hit  → read unsorted normalized source payload
        │       │       └── miss → call provider, normalize once, write source cache
        │       │
        │       └── Return normalized source results
        │
        ├── Add normalized source results to all-tab state
        │
        ├── Rerank candidate pool while preserving already-visible order
        │
        ├── Write reranked all-tab state to cache
        │
        └── Return requested stable display slice
    │
    ▼
Render results
```

## Consequences

Redis should store smaller, application-shaped payloads for single-source search results. Cache hits should avoid both
external API calls and normalization work.

All-tab load-more may continue to use more cache space than a single-source request because it stores state for the
reranked result set. This is intentional. The additional state lets the application preserve already-visible result
order while adding newly fetched and reranked candidates on later load-more requests.

The application will become more dependent on the normalized record contract. Changes to normalized record shape are
also cache-shape changes, so cache versioning or namespacing will be necessary when that contract changes. For example,
if we add a new normalized `availability` field that search result views expect to be present, existing cached
normalized payloads would not include that field. The implementation should use a new cache namespace or schema version
for that change so requests do not read older cached payloads that no longer match the current normalized record
contract.

The raw provider response will no longer be available from the search result cache. If future behavior requires fields
that are not present in normalized results, those fields should be added deliberately to the normalized payload rather
than relying on provider-specific raw data.

Tests should verify that cached single-source Primo and TIMDEX results preserve user-visible behavior, including hit
counts, pagination behavior, errors, and Primo continuation behavior. Tests should also verify that cache hits avoid
external provider calls and normalizer instantiation.
