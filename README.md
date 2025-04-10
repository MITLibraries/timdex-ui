[![Maintainability](https://api.codeclimate.com/v1/badges/d766c34cd3d13be411e2/maintainability)](https://codeclimate.com/github/MITLibraries/timdex-ui/maintainability)

# TIMDEX UI

A discovery interface backed by [the TIMDEX API](https://github.com/MITLibraries/timdex).

## Architecture decision records (ADRs)

This repository contains ADRs in the docs/architecture-decisions directory.

adr-tools should allow easy creation of additional records with a standardized template.

## TIMDEX UI Flow Diagram

Note: this is a logical flow diagram and not a direct representation of object relationships. It is also a guide, not
a set of rules to follow. If implementation is done differently, please update this diagram to reflect that intentional
change as part of the work.

```mermaid
  flowchart TD
    UserInput --> Enhancer
    UserInputAdvanced --> Enhancer

    Enhancer --> QueryBuilder

    QueryBuilder --> Timdex

    Timdex --> Results --> Analyzer
    Timdex --> Errors
    Errors --> UI

    Analyzer --> Records --> UI
    Analyzer --> Facets --> UI
    Analyzer --> Pagination --> UI
    Analyzer --> Info --> UI

    Enhancer --> Actions
    
    Actions --> Info

    Analyzer("Analyzer 🔎")
    Enhancer("Enhancer 🔎")
    Errors("Errors ‼️")
    Info("Info ℹ️")
    Pagination("Pagination 🔢")
    Records("Records 📚")
    UI("Results UI 🤩")
    UserInput("User Input 🤷🏽‍♀️")
    UserInputAdvanced("User Input Advanced 🦸‍♀️")
```

## Developer notes

### Confirming functionality after dependency updates

This application has test coverage >95%, so running the test suite is likely sufficient to confirm
functionality in most cases. Some click testing is also useful, particularly if there have been
updates to `graphql-ruby` or `graphql-client`:

1. Confirm that basic and advanced searches do not error and return results.
2. Confirm that geospatial searches (bounding box and distance) do not error and return results. (Note that this
requires testing against an index that contains geospatial records.)
3. Confirm that filters from multiple categories can be applied and removed, both on the sidebar
and the panel beneath the search form.

If the `flipflop` gem has been updated, check that the `:gdt` feature is working by ensuring that
UI elements specific to GDT (e.g., geospatial search fields or the 'Ask GIS' link) appear with the
feature flag enabled, and do not when it is disabled.

### CloudFlare Turnstile

This application uses [CloudFlare Turnstile](https://www.cloudflare.com/application-services/products/turnstile/) via
the [Bot Challenge Page](https://github.com/samvera-labs/bot_challenge_page) gem.

In development, you can enable/disable this by running `rails dev:cache`. When `dev:cache` is not enabled, the cache is
set to `null` so no enforcement is in place. As we do not register `localhost` with CloudFlare, if you have `dev:cache`
enabled locally, you won't actually see the Turnstile challenge and instead will see a message saying you have been
blocked. This is what users would also see if a deployed app is not registered with CloudFlare so we need to ensure all
apps we intend to protect are registered with the site key we have enabled.

`Bot Challenge Page` uses [rack-attack](https://github.com/rack/rack-attack). On Heroku deployed apps, we'll be using
Redis to track requests.

See `Optional Environment Variables` for more information.

### Rack Attack

This application uses [Rack Attack](https://github.com/rack/rack-attack).

See `Optional Environment Variables` for more information.

### Required Environment Variables

- `TIMDEX_GRAPHQL`: Set this to the URL of the GraphQL endpoint. There is no default value in the application.

### Optional Environment Variables

- `ABOUT_APP`: If populated, an 'about' partial containing the contents of this variable will render on 
`basic_search#index`.
- `ACTIVE_FILTERS`: If populated, this list of strings defines which filters are shown to the user, and the order in which they appear. Values are case sensitive, and must match the corresponding aggregations used in the TIMDEX GraphQL query. Extraneous values will be ignored. If not populated, all filters will be shown.
- `BOOLEAN_OPTIONS`: comma separated list of values to present to testers on instances where `BOOLEAN_PICKER` feature is enabled.
- `BOOLEAN_PICKER`: feature to allow users to select their preferred boolean type. If set, feature is enabled. This feature is only intended for internal team
  testing and should never be enabled in production (mostly because the UI is a mess more than it would cause harm).
- `CLOUDFLARE_SITE_KEY`: obtained through our cloudflare account (see lastpass for account info)
- `CLOUDFLARE_SECRET_KEY`: obtained through our cloudflare account (see lastpass for account info)
- `CLOUDFLARE_REQUEST_PERIOD_IN_HOURS`: integer in hours we use for grouping requests. Combined with `CLOUDFLARE_REQUESTS_PER_PERIOD` this makes up the "requests allowed per time period". Defaults to 12.
- `CLOUDFLARE_REQUESTS_PER_PERIOD`: integer representing number of results and records pages allowed in the period defined in `CLOUDFLARE_REQUEST_PERIOD_IN_HOURS`. Defaults to 10.
- `FACT_PANELS_ENABLED`: Comma separated list of enabled fact panels. See `/views/results.html.erb` for implemented panels/valid options. Leave unset to disable all.
- `FILTER_ACCESS_TO_FILES`: The name to use instead of "Access to files" for that filter / aggregation.
- `FILTER_CONTENT_TYPE`: The name to use instead of "Content type" for that filter / aggregation.
- `FILTER_CONTRIBUTOR`: The name to use instead of "Contributor" for that filter / aggregation.
- `FILTER_FORMAT`: The name to use instead of "Format" for that filter / aggregation.
- `FILTER_LANGUAGE`: The name to use instead of "Language" for that filter / aggregation.
- `FILTER_LITERARY_FORM`: The name to use instead of "Literary form" for that filter / aggregation.
- `FILTER_PLACE`: The name to use instead of "Place" for that filter / aggregation.
- `FILTER_SOURCE`: The name to use instead of "Source" for that filter / aggregation.
- `FILTER_SUBJECT`: The name to use instead of "Subject" for that filter / aggregation.
- `GDT`: Enables features related to geospatial data discovery. Setting this variable with any value will trigger GDT
mode (e.g., `GDT=false` will still enable GDT features). Note that this is currently intended _only_ for the GDT app and
may have unexpected consequences if applied to other TIMDEX UI apps.
- `GLOBAL_ALERT`: The main functionality for this comes from our theme gem, but when set the value will be rendered as
  safe html above the main header of the site.
- `PLATFORM_NAME`: The value set is added to the header after the MIT Libraries logo. The logic and CSS for this comes from our theme gem.
- `REQUESTS_PER_PERIOD` - number of requests that can be made for general throttles per `REQUEST_PERIOD`
- `REQUEST_PERIOD` - time in minutes used along with `REQUESTS_PER_PERIOD`
- `REDIRECT_REQUESTS_PER_PERIOD`- number of requests that can be made that the query string starts with our legacy redirect parameter to throttle per `REQUEST_PERIOD`
- `REDIRECT_REQUEST_PERIOD`- time in minutes used along with `REDIRECT_REQUEST_PERIOD`
- `SENTRY_DSN`: Client key for Sentry exception logging.
- `SENTRY_ENV`: Sentry environment for the application. Defaults to 'unknown' if unset.
- `TIMDEX_INDEX`: Name of the index, or alias, to provide to the GraphQL endpoint. Defaults to `nil` which will let TIMDEX determine the best index to use. Wildcard values can be set, for example `rdi*` would search any indexes that begin with `rdi` in the underlying OpenSearch instance behind TIMDEX.
- `TIMDEX_SOURCES`: Comma-separated list of sources to display in the advanced-search source selection element. This
  overrides the default which is set in ApplicationHelper.

#### Test Environment-only Variables

- `SPEC_REPORTER`: Optional variable. If set, enables spec reporter style output from tests rather than minimal output.
- `TIMDEX_HOST`: Test Env only. Used to ensure the VCR cassettes can properly scrub specific host data to make sure we get the same cassettes regardless of which host was used to generate the cassettes. This should be set to the host name that matches `TIMDEX_GRAPHQL`. Ex: If `TIMDEX_GRAPHQL` is `https://www.example.com/graphql` then `TIMDEX_HOST` should be `www.example.com`.

### Generating VCR Cassettes

When generating new cassettes for timdex-ui, update `.env.test` to have appropriate values for your test for `TIMDEX_GRAPHQL` and `TIMDEX_HOST`. This will allow the cassettes to be generated from any TIMDEX source with the data you need, but be sure to set them back to the original values after the cassette are generated. When the values are not set to the "fake" values we normally store, many tests will fail due to how the cassettes re-write values to normalize what we store.

`.env.test` should be commited to the repository, but should not include real values for a TIMDEX source even though they are not secrets. We want to use fake values to allow us to normalize our cassettes without forcing us to always generate them from a single TIMDEX source.

### Updating GraphQL Schema

The schema for the GraphQL endpoint can be found at `/config/schema/schema.json`. This schema is used by the graphql-client gem, and so must be kept in sync with the Timdex GraphQL API. Updating the schema can be accomplished via the following command in the console:

```ruby
GraphQL::Client.dump_schema(TimdexBase::HTTP, 'config/schema/schema.json')
```
