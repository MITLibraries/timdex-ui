class Analyzer
  attr_accessor :pagination

  RESULTS_PER_PAGE = 20

  def initialize(enhanced_query, response)
    @pagination = {}
    @pagination[:hits] = response&.data&.search&.to_h&.dig('hits')
    @pagination[:page] = enhanced_query[:page]
    @pagination[:prev] = enhanced_query[:page] - 1 if enhanced_query[:page] > 1
    @pagination[:next] = next_page(enhanced_query[:page], @pagination[:hits])
  end

  private

  def next_page(page, hits)
    page + 1 if page * RESULTS_PER_PAGE < hits
  end
end
