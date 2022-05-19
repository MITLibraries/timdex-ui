require 'graphql/client'
require 'graphql/client/http'

class TimdexCandy
  def search(query, values)
    client.query(query, variables: values)
  end

  # The below would be private methods

  def client
    GraphQL::Client.new(schema:, execute: http)
  end

  def http
    GraphQL::Client::HTTP.new(timdex_url) do
      def headers(*)
        { 'User-Agent': 'MIT Libraries Client' }
      end
    end
  end

  def schema
    GraphQL::Client.load_schema('config/schema/schema.json')
  end

  def timdex_url
    ENV.fetch('TIMDEX_GRAPHQL', '')
  end

  SearchQueryText = <<-'GRAPHQL'.freeze
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
