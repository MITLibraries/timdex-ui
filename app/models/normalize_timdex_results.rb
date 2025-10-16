# Batch normalization for TIMDEX API results
class NormalizeTimdexResults
  def initialize(results, query)
    @results = results
    @query = query
  end

  def normalize
    return [] unless @results.is_a?(Array)

    @results.filter_map do |doc|
      NormalizeTimdexRecord.new(doc, @query).normalize
    end
  end
end
