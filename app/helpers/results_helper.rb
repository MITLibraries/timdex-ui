module ResultsHelper
  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ items' : "#{number_with_delimiter(hits)} items"
  end
end
