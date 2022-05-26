class QueryBuilder
  attr_reader :query

  RESULTS_PER_PAGE = 20

  def initialize(enhanced_query)
    term = enhanced_query[:q]
    @query = {}
    @query['q'] = clean_term(term)
    @query['from'] = calculate_from(enhanced_query[:page])
  end

  def querystring
    @query.to_query
  end

  private

  def calculate_from(page = 1)
    # This needs to return a string because Timdex needs $from to be a String
    page = 1 if page.to_i.zero?
    ((page - 1) * RESULTS_PER_PAGE).to_s
  end

  def clean_term(term)
    term.gsub('"', '\'').strip
  end
end
