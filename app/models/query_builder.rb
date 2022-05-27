class QueryBuilder
  attr_reader :query

  def initialize(enhanced_query)
    term = enhanced_query[:q]
    @query = {}
    @query['q'] = clean_term(term)
  end

  def querystring
    @query.to_query
  end

  private

  def clean_term(term)
    term.gsub('"', '\'').strip
  end
end
