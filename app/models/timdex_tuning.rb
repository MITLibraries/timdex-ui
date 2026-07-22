# frozen_string_literal: true

# This class exists because we rely on some undocumented parameters for tuning system performance, and using those
# parameters in conjunction with the graphql-client gem results in schema validation errors (because the parameters
# are not found in the schema).
class TimdexTuning
  TUNING_QUERY = <<-GRAPHQL
    query TimdexPlaygroundQuery(
      $q: String,
      $citation: String,
      $contributors: String,
      $fundingInformation: String,
      $identifiers: String,
      $locations: String,
      $subjects: String,
      $title: String,
      $index: String,
      $from: String,
      $booleanType: String,
      $queryMode: String,
      $fulltext: Boolean,
      $perPage: Int,
      $accessToFilesFilter: [String!],
      $contentTypeFilter: [String!],
      $contributorsFilter: [String!],
      $formatFilter: [String!],
      $languagesFilter: [String!],
      $literaryFormFilter: String,
      $placesFilter: [String!],
      $sourceFilter: [String!],
      $subjectsFilter: [String!],
      $useGlobalScoring: Boolean,
      $semanticDropBoostThreshold: Float,
      $semanticMustBoostThreshold: Float,
      $semanticShortQueryMaxTokens: Int
    ) {
      search(
        searchterm: $q
        citation: $citation
        contributors: $contributors
        fundingInformation: $fundingInformation
        identifiers: $identifiers
        locations: $locations
        subjects: $subjects
        title: $title
        index: $index
        from: $from
        booleanType: $booleanType
        queryMode: $queryMode
        fulltext: $fulltext
        perPage: $perPage
        accessToFilesFilter: $accessToFilesFilter
        contentTypeFilter: $contentTypeFilter
        contributorsFilter: $contributorsFilter
        formatFilter: $formatFilter
        languagesFilter: $languagesFilter
        literaryFormFilter: $literaryFormFilter
        placesFilter: $placesFilter
        sourceFilter: $sourceFilter
        subjectsFilter: $subjectsFilter
        useGlobalScoring: $useGlobalScoring
        semanticDropBoostThreshold: $semanticDropBoostThreshold
        semanticMustBoostThreshold: $semanticMustBoostThreshold
        semanticShortQueryMaxTokens: $semanticShortQueryMaxTokens
      ) {
        hits
        records {
          timdexRecordId
          identifiers {
            kind
            value
          }
          title
          source
          contentType
          contributors {
            kind
            value
          }
          publicationInformation
          dates {
            kind
            value
            range {
              gte
              lte
            }
          }
          links {
            kind
            restrictions
            text
            url
          }
          notes {
            kind
            value
          }
          highlight {
            matchedField
            matchedPhrases
          }
          provider
          rights {
            kind
            description
            uri
          }
          sourceLink
          summary
          subjects {
            kind
            value
          }
          citation
        }
        aggregations {
          accessToFiles {
            key
            docCount
          }
          contentType {
            key
            docCount
          }
          contributors {
            key
            docCount
          }
          format {
            key
            docCount
          }
          languages {
            key
            docCount
          }
          literaryForm {
            key
            docCount
          }
          places {
            key
            docCount
          }
          source {
            key
            docCount
          }
          subjects {
            key
            docCount
          }
        }
      }
    }
  GRAPHQL
end
