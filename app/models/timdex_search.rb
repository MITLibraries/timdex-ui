require 'graphql/client'
require 'graphql/client/http'

class TimdexSearch < TimdexBase
  BaseQuery = TimdexBase::Client.parse <<-GRAPHQL
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
      $booleanType: String
      $accessToFilesFilter: [String!]
      $contentTypeFilter: [String!]
      $contributorsFilter: [String!]
      $formatFilter: [String!]
      $languagesFilter: [String!]
      $literaryFormFilter: String
      $placesFilter: [String!]
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
        booleanType: $booleanType
        accessToFilesFilter: $accessToFilesFilter
        contentTypeFilter: $contentTypeFilter
        contributorsFilter: $contributorsFilter
        formatFilter: $formatFilter
        languagesFilter: $languagesFilter
        literaryFormFilter: $literaryFormFilter
        placesFilter: $placesFilter
        sourceFilter: $sourceFilter
        subjectsFilter: $subjectsFilter
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

  GeoboxQuery = TimdexBase::Client.parse <<-GRAPHQL
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
      $booleanType: String
      $geoboxMinLatitude: Float!
      $geoboxMinLongitude: Float!
      $geoboxMaxLatitude: Float!
      $geoboxMaxLongitude: Float!
      $accessToFilesFilter: [String!]
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
        booleanType: $booleanType
        geobox: {
          minLongitude: $geoboxMinLongitude,
          minLatitude: $geoboxMinLatitude,
          maxLongitude: $geoboxMaxLongitude,
          maxLatitude: $geoboxMaxLatitude
        }
        accessToFilesFilter: $accessToFilesFilter
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

  GeodistanceQuery = TimdexBase::Client.parse <<-GRAPHQL
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
      $booleanType: String
      $accessToFilesFilter: [String!]
      $geodistanceDistance: String!
      $geodistanceLatitude: Float!
      $geodistanceLongitude: Float!
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
        booleanType: $booleanType
        geodistance: {
          distance: $geodistanceDistance,
          latitude: $geodistanceLatitude,
          longitude: $geodistanceLongitude
        }
        accessToFilesFilter: $accessToFilesFilter
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

  AllQuery = TimdexBase::Client.parse <<-GRAPHQL
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
      $booleanType: String
      $accessToFilesFilter: [String!]
      $geodistanceDistance: String!
      $geodistanceLatitude: Float!
      $geodistanceLongitude: Float!
      $geoboxMinLatitude: Float!
      $geoboxMinLongitude: Float!
      $geoboxMaxLatitude: Float!
      $geoboxMaxLongitude: Float!
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
        booleanType: $booleanType
        geodistance: {
          distance: $geodistanceDistance,
          latitude: $geodistanceLatitude,
          longitude: $geodistanceLongitude
        }
        geobox: {
          minLongitude: $geoboxMinLongitude,
          minLatitude: $geoboxMinLatitude,
          maxLongitude: $geoboxMaxLongitude,
          maxLatitude: $geoboxMaxLatitude
        }
        accessToFilesFilter: $accessToFilesFilter
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
