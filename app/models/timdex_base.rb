require 'graphql/client'
require 'graphql/client/http'

class TimdexBase
  HTTP = GraphQL::Client::HTTP.new(ENV.fetch('TIMDEX_GRAPHQL', '')) do
    def headers(*)
      { 'User-Agent': 'MIT Libraries Client' }
    end
  end

  Schema = GraphQL::Client.load_schema('config/schema/schema.json')

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
