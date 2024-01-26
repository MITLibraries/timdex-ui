# 2. Extend TIMDEX UI for GIS data

Date: 2024-01-24

## Status

Accepted

## Context

The [GIS Data Tool (GDT) project](https://mitlibraries.atlassian.net/jira/software/c/projects/GDT/boards/225)
requires a discovery interface for GIS data. The project team has made the decision to extend TIMDEX UI for this
purpose.

This approach necessarily adds some complexity to the TIMDEX UI codebase. Generally, the UI design changes proposed for
GDT fall into three categories:

* Changes that are unique to the GDT app (e.g., app name in the header, 'Ask GIS' sidebar widget);
* Changes that should apply to all TIMDEX UI apps (e.g., filter sidebar redesign, IA enhancements); and
* Changes that are currenty unique to the GDT app, but may later apply other other TIMDEX UI apps (e.g., geospatial
querying, filters that are specific to geospatial data).

General UI enhancements should be straightforward to implement across all TIMDEX UI applications. However, we will also
need to develop the GDT UI without disrupting existing TIMDEX UI implementations, while considering the future
possibility of integrating geospatial search into those applications.

These are the potential solutions we have considered:

### Feature flags

Using the [`flipflop` gem](https://github.com/voormedia/flipflop), we can add a `GDT` feature that is toggled by an
environment variable. We've implemented this in many of our Rails apps and found that it's an effective way to manage
multiple versions of an application (most recently, in TIMDEX API). The downside of using `flipflop` is that it does
not appear to be especially well maintained, but we're familiar with it and have used it successfully in the past.

### Index detection

Since geospatial records will be in a separate index at first, we can check for the index the app is using (currently
defined in in an environment variable) to determine which UI elements to display and which type of query to construct.
This would solve the problem similarly to feature flags. It does not account for the possible future state of geospatial
data existing in other indices, but it could solve the immediate need of maintaining GDT features separately.

### Search params

Bento uses a `target` param to identify which source is being queried. We could implement a similar design pattern in
TIMDEX UI to distinguish between geospatial queries and 'general' queries. This would likely include a boolean in the
search form that would trigger a geospatial query. In addition to providing the query target, we could use the param
value to evaluate whether to add GIS-specific UI elements to the results view.

Like index detection, this is duplicative of the feature flags approach, but it would allow us to achieve a similar
effect without using an external dependency. However, this would not be a consistent solution for the full record view,
as direct linking is a common use case for full records, and we may not be able to guarantee the presence of a `gis=true`
param in these links.

One use case where search params could be useful is the potential future state in which `search.libraries.mit.edu` (or
another TIMDEX UI app) includes GIS data in search results. In that instance, it may be valuable to allow users to
choose whether they want geospatial data queried in their search.

### Data detection

We could check for the presence of certain fields in the API response to determine which UI elements to display. If
geospatial records are in the results, then GDT-specific fields would appear in the brief and full record, and
GDT-specific filters would appear in the sidebar. This would help address the use case of adding geospatial data to
indices searched by non-GDT applications. 

### Theme gem

We can use the theme gem to conditionally modify certain views that are shared across our Rails properties. This would
solve the problem of customizing the header, but not views that are specific to the GDT UI.

## Decisions

We will extend TIMDEX UI for GIS data using a combination of the solutions described above:

* We will create a separate Heroku app in the TIMDEX UI pipeline for GDT.
* Where possible and reasonable, local header customizations will be controlled by the theme gem.
* We will use `flipflop` to implement a GDT feature flag, which will toggle GDT-specific features.
* We will add universal UI improvements to all TIMDEX UI implementations.
* In the future, we will consider adding a `gis` search param and/or a data detection enhancer as needed.

If we decide to add geospatial data  to other TIMDEX UI applications in the future, we can decide whether a search param
or data detection approach will be more effective. (Note that this decision will likely require us to modify how our
feature flag is implemented, or to replace it altogether.)

We will not use index detection, as it does not address any additional use cases.

## Consequences

Using the theme gem for header customizations may be useful for other applications. We can minimize repetition by
managing these changes in environment variables read by the theme gem, but we should be wary of overabstraction. We will
try this with adding the app name to the header to start, and carefully consider whether it may be useful for other UI
elements.

The feature flag will serve as an initial solution to isolating GDT UI features. Because we have used `flipflop` before,
it should not significantly impact development time, which is an important consideration at this point in the project.

There may be additional use cases we haven't yet considered that could impact this decision. We should remain open to
changing our approach as the project develops.
