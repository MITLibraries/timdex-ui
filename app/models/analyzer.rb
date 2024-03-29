class Analyzer
  attr_accessor :pagination

  RESULTS_PER_PAGE = 20

  def initialize(enhanced_query, response)
    @pagination = {}
    @pagination[:hits] = hits(response)
    @pagination[:start] = ((enhanced_query[:page] - 1) * RESULTS_PER_PAGE) + 1
    @pagination[:end] = [enhanced_query[:page] * RESULTS_PER_PAGE, hits(response)].min
    @pagination[:prev] = enhanced_query[:page] - 1 if enhanced_query[:page] > 1
    @pagination[:next] = next_page(enhanced_query[:page], @pagination[:hits])
  end

  private

  def hits(response)
    response&.data&.search&.to_h&.dig('hits')
  end

  def next_page(page, hits)
    page + 1 if page * RESULTS_PER_PAGE < hits
  end
end
