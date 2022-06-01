require 'graphql/client'
require 'graphql/client/http'

class TimdexRecord < TimdexBase
  Query = TimdexBase::Client.parse <<-'GRAPHQL'
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
end
