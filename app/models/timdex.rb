require 'graphql/client'
require 'graphql/client/http'

class Timdex
  HTTP = GraphQL::Client::HTTP.new(ENV.fetch('TIMDEX_GRAPHQL', '')) do
    def headers(*)
      { 'User-Agent': 'MIT Libraries Client' }
    end
  end

  Schema = GraphQL::Client.load_schema('config/schema/schema.json')

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  SearchQuery = Timdex::Client.parse <<-'GRAPHQL'
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
