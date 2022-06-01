require 'graphql/client'
require 'graphql/client/http'

class TimdexSearch < TimdexBase
  Query = TimdexBase::Client.parse <<-'GRAPHQL'
    query($q: String!) {
      search(searchterm: $q) {
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
