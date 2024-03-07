require 'graphql/client'
require 'graphql/client/http'

class TimdexSearch < TimdexBase
  Query = TimdexBase::Client.parse <<-'GRAPHQL'
    query(
      $q: String
      $citation: String
      $contributors: String
      $fundingInformation: String
      $identifiers: String
      $locations: String
      $subjects: String
      $title: String
      $index: String
      $from: String
      $contentTypeFilter: [String!]
      $contributorsFilter: [String!]
      $formatFilter: [String!]
      $languagesFilter: [String!]
      $literaryFormFilter: String
      $sourceFilter: [String!]
      $subjectsFilter: [String!]
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
        contentTypeFilter: $contentTypeFilter
        contributorsFilter: $contributorsFilter
        formatFilter: $formatFilter
        languagesFilter: $languagesFilter
        literaryFormFilter: $literaryFormFilter
        sourceFilter: $sourceFilter
        subjectsFilter: $subjectsFilter
      ) {
        hits
        records {
          timdexRecordId
          title
          contentType
          contributors {
            kind
            value
          }
          publicationInformation
          dates {
            kind
            value
          }
          notes {
            kind
            value
          }
          highlight {
            matchedField
            matchedPhrases
          }
          sourceLink
        }
        aggregations {
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
