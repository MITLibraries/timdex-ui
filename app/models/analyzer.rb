class Analyzer
  attr_accessor :pagination

  # Primo API theoretical maximum recommended offset is 2000 records (per Ex Libris documentation)
  # but in practice, the API often can't deliver results beyond ~960 records for large result sets,
  # likely due to performance constraints.
  PRIMO_MAX_OFFSET = 960

  # Initializes pagination analysis for search results.
  #
  # @param enhanced_query [Hash] Query parameters including :page (current page number)
  # @param hits [Integer] Number of hits from primary source (TIMDEX for :all, source-specific otherwise)
  # @param source [Symbol] Source tab (:primo, :timdex, or :all)
  # @param secondary_hits [Integer, nil] Optional hit count from secondary source (Primo hits for :all)
  def initialize(enhanced_query, hits, source, secondary_hits = nil)
    @source = source
    @enhanced_query = enhanced_query
    @pagination = {}
    set_pagination(hits, secondary_hits)
  end

  private

  # Sets the pagination hash with hit counts and per_page values.
  #
  # @param hits [Integer] Hit count from primary source
  # @param secondary_hits [Integer, nil] Optional hit count from secondary source
  def set_pagination(hits, secondary_hits = nil)
    if @source == :all
      @pagination[:hits] = (secondary_hits || 0) + (hits || 0)
      @pagination[:per_page] = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
      calculate_pagination_values
    else
      @pagination[:hits] = hits || 0
      @pagination[:per_page] = ENV.fetch('RESULTS_PER_PAGE', '20').to_i
      calculate_pagination_values
    end
  end

  # Calculates and sets pagination navigation values (start, end, prev, next).
  # Uses the already-set @pagination[:hits] and @pagination[:per_page] values.
  def calculate_pagination_values
    page = @enhanced_query[:page] || 1
    @pagination[:start] = ((page - 1) * @pagination[:per_page]) + 1
    @pagination[:end] = [page * @pagination[:per_page], @pagination[:hits]].min
    @pagination[:prev] = page - 1 if page > 1
    @pagination[:next] = next_page(page, @pagination[:hits]) if next_page(page, @pagination[:hits])
  end

  # Calculates the next page number if more results are available.
  #
  # @param page [Integer] Current page number
  # @param hits [Integer] Total number of results available
  # @return [Integer, nil] Next page number or nil if no more pages
  def next_page(page, hits)
    page + 1 if page * @pagination[:per_page] < hits
  end
end
