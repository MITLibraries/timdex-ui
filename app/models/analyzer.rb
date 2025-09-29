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
    return 0 if response.nil?
    return 0 unless response.is_a?(Hash) && response.key?(:data) && response[:data].key?('search')
    return 0 unless response[:data]['search'].is_a?(Hash) && response[:data]['search'].key?('hits')

    response[:data]['search']['hits']
  end

  def next_page(page, hits)
    page + 1 if page * RESULTS_PER_PAGE < hits
  end
end
