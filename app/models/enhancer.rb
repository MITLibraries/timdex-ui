class Enhancer
  attr_accessor :enhanced_query

  # accepts all params as each enhancer may require different data
  def initialize(params)
    @enhanced_query = {}
    @enhanced_query[:q] = params[:q] if params[:q]
    patterns(params) if params[:q]
  end

  private

  def patterns(params)
    @enhanced_query = EnhancerPatterns.new(@enhanced_query, params[:q]).enhanced_query
  end
end
