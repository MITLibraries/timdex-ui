module QueryElements
  QUERY_PARAMS = %i[q citation contentType contributors fundingInformation identifiers locations subjects title].freeze
  FILTER_PARAMS = %i[accessToFilesFilter contentTypeFilter contributorsFilter formatFilter languagesFilter
                     literaryFormFilter placesFilter sourceFilter subjectsFilter].freeze
  GEO_PARAMS = %i[geoboxMinLongitude geoboxMinLatitude geoboxMaxLongitude geoboxMaxLatitude geodistanceLatitude
                  geodistanceLongitude geodistanceDistance].freeze
  RESULTS_PER_PAGE = 20
end
