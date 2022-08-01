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
      $sourceFacet: [String!]
      $index: String
      $from: String
      $contentType: [String!]
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
        sourceFacet: $sourceFacet
        index: $index
        from: $from
        contentTypeFacet: $contentType
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
          source {
            key
            docCount
          }
        }
      }
    }
  GRAPHQL
end
