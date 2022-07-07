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
      $from: String
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
        from: $from
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
        }
        aggregations {
          contentFormat {
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
