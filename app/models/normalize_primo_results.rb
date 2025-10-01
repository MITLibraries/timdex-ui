# Batch normalization for Primo Search API results
class NormalizePrimoResults
  def initialize(results, query)
    @results = results
    @query = query
  end

  def normalize
    return [] unless @results&.dig('docs')

    @results['docs'].filter_map do |doc|
      NormalizePrimoRecord.new(doc, @query).normalize
    end
  end

  def total_results
    @results&.dig('info', 'total') || 0
  end
end
