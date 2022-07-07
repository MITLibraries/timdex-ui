class Enhancer
  attr_accessor :enhanced_query

  QUERY_PARAMS = %i[q citation contentType contributors fundingInformation identifiers locations subjects title].freeze
  FILTER_PARAMS = [:source].freeze
  # accepts all params as each enhancer may require different data
  def initialize(params)
    @enhanced_query = {}
    @enhanced_query[:page] = calculate_page(params[:page].to_i)
    @enhanced_query[:advanced] = true if params[:advanced].present?

    extract_query(params)
    extract_filters(params)
    patterns(params) if params[:q]
  end

  private

  def calculate_page(value = 0)
    value < 1 ? 1 : value
  end

  def extract_query(params)
    QUERY_PARAMS.each do |qp|
      @enhanced_query[qp] = params[qp] if params[qp].present?
    end
  end

  def extract_filters(params)
    FILTER_PARAMS.each do |fp|
      @enhanced_query[fp] = params[fp] if params[fp].present?
    end
  end

  def patterns(params)
    @enhanced_query = EnhancerPatterns.new(@enhanced_query, params[:q]).enhanced_query
  end
end
