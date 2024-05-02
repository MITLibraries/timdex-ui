module ResultsHelper
  def fact_enabled?(fact_type)
    ENV.fetch('FACT_PANELS_ENABLED', false).split(',').include?(fact_type)
  end

  def results_summary(hits)
    hits.to_i >= 10_000 ? '10,000+ results' : "#{number_with_delimiter(hits)} results"
  end
end
