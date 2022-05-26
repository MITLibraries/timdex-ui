require 'graphql/client'
require 'graphql/client/http'

class Timdex
  HTTP = GraphQL::Client::HTTP.new(ENV.fetch('TIMDEX_GRAPHQL', '')) do
    def headers(*)
      {
        'User-Agent': 'MIT Libraries Client',
        'Origin': ENV.fetch('TIMDEX_UI_ORIGIN', 'http://localhost:3000')
      }
    end
  end

  Schema = GraphQL::Client.load_schema('config/schema/schema.json')

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  RecordQuery = Timdex::Client.parse <<-'GRAPHQL'
    query($id: String!) {
      recordId(id: $id) {
        alternateTitles {
          kind
          value
        }
        callNumbers
        contentType
        contents
        contributors {
          affiliation
          identifier
          kind
          mitAffiliated
          value
        }
        dates {
          kind
          note
          range {
            gte
            lte
          }
          value
        }
        edition
        # fileFormats
        # format
        fundingInformation {
          funderName
          funderIdentifier
          funderIdentifierType
          awardUri
          awardNumber
        }
        holdings {
          callnumber
          collection
          format
          location
          notes
          summary
        }
        identifiers {
          kind
          value
        }
        languages
        links {
          kind
          restrictions
          text
          url
        }
        literaryForm
        locations {
          geopoint
          kind
          value
        }
        notes {
          kind
          value
        }
        numbering
        physicalDescription
        publicationFrequency
        publicationInformation
        relatedItems {
          description
          itemType
          relationship
          uri
        }
        rights {
          description
          kind
          uri
        }
        source
        sourceLink
        subjects {
          kind
          value
        }
        summary
        timdexRecordId
        title
      }
    }
  GRAPHQL

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
