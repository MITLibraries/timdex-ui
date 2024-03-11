class QueryBuilder
  attr_reader :query

  RESULTS_PER_PAGE = 20
  QUERY_PARAMS = %w[q citation contributors fundingInformation identifiers locations subjects title].freeze
  FILTER_PARAMS = %i[contentTypeFilter contributorsFilter formatFilter languagesFilter literaryFormFilter placesFilter
                     sourceFilter subjectsFilter].freeze

  def initialize(enhanced_query)
    @query = {}
    @query['from'] = calculate_from(enhanced_query[:page])
    extract_query(enhanced_query)
    extract_filters(enhanced_query)
    @query['index'] = ENV.fetch('TIMDEX_INDEX', nil)
    @query.compact!
  end

  private

  def calculate_from(page = 1)
    # This needs to return a string because Timdex needs $from to be a String
    page = 1 if page.to_i.zero?
    ((page - 1) * RESULTS_PER_PAGE).to_s
  end

  def extract_query(enhanced_query)
    QUERY_PARAMS.each do |qp|
      @query[qp] = enhanced_query[qp.to_sym]&.strip
    end
  end

  def extract_filters(enhanced_query)
    FILTER_PARAMS.each do |qp|
      @query[qp] = enhanced_query[qp]
    end
  end
end
