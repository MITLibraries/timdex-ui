class Enhancer
  attr_accessor :enhanced_query

  # accepts all params as each enhancer may require different data
  def initialize(params)
    @enhanced_query = {}
    @enhanced_query[:q] = params[:q] if params[:q]
    @enhanced_query[:page] = calculate_page(params[:page].to_i)
    patterns(params) if params[:q]
  end

  private

  def calculate_page(value = 0)
    # This needs to return a positive integer.
    value < 1 ? 1 : value
  end

  def patterns(params)
    @enhanced_query = EnhancerPatterns.new(@enhanced_query, params[:q]).enhanced_query
  end
end
