class Analyzer
  attr_accessor :pagination

  RESULTS_PER_PAGE = 20

  # Primo API theoretical maximum recommended offset is 2000 records (per Ex Libris documentation)
  # but in practice, the API often can't deliver results beyond ~960 records for large result sets,
  # likely due to performance constraints.
  PRIMO_MAX_OFFSET = 960

  def initialize(enhanced_query, response, source)
    @source = source
    @pagination = {}
    @pagination[:hits] = hits(response)
    @pagination[:start] = ((enhanced_query[:page] - 1) * RESULTS_PER_PAGE) + 1
    @pagination[:end] = [enhanced_query[:page] * RESULTS_PER_PAGE, @pagination[:hits]].min
    @pagination[:prev] = enhanced_query[:page] - 1 if enhanced_query[:page] > 1

    next_page_num = next_page(enhanced_query[:page], @pagination[:hits])
    @pagination[:next] = next_page_num if next_page_num
  end

  private

  def hits(response)
    return 0 if response.nil?

    if @source == :primo
      primo_hits(response)
    elsif @source == :timdex
      timdex_hits(response)
    else
      0
    end
  end

  def primo_hits(response)
    return 0 unless response.is_a?(Hash)

    response.dig('info', 'total') || 0
  end

  def timdex_hits(response)
    return 0 unless response.is_a?(Hash) && response.key?(:data) && response[:data].key?('search')
    return 0 unless response[:data]['search'].is_a?(Hash) && response[:data]['search'].key?('hits')

    response[:data]['search']['hits']
  end

  def next_page(page, hits)
    page + 1 if page * RESULTS_PER_PAGE < hits
  end
end
