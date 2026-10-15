# Batch normalization for Primo Search API results
class NormalizePrimoResults
  attr_reader :frbr_group_ids

  def initialize(results, query)
    @results = results
    @query = query
    @frbr_group_ids = []
  end

  def normalize
    docs = Array(@results&.dig('docs'))

    # Collects FRBR group IDs found in Primo response to add to the log payload in the search
    # controller.
    @frbr_group_ids = extract_frbr_group_ids(docs)

    docs.filter_map do |doc|
      NormalizePrimoRecord.new(doc, @query).normalize
    end
  end

  def total_results
    @results&.dig('info', 'total') || 0
  end

  private

  def extract_frbr_group_ids(docs)
    docs.flat_map { |doc| frbr_group_ids_for(doc) }.uniq
  end

  def frbr_group_ids_for(doc)
    facets = doc&.dig('pnx', 'facets')
    return [] unless frbrized?(facets)

    Array(facets['frbrgroupid']).filter_map do |group_id|
      normalized = group_id.to_s.strip
      normalized unless normalized.empty?
    end
  end

  def frbrized?(facets)
    Array(facets&.dig('frbrtype')).join == '5'
  end
end
