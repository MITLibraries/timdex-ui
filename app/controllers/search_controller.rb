class SearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  layout false

  def results
    # hand off to Enhancer chain
    @enhanced_query = Enhancer.new(params).enhanced_query

    # hand off enhanced query to builder
    query = QueryBuilder.new(@enhanced_query).query

    # builder hands off to wrapper which returns raw results here
    response = TimdexBase::Client.query(TimdexSearch::Query, variables: query)

    # Handle errors
    @errors = extract_errors(response)

    # Analayze results
    # The @pagination instance variable includes info about next/previous pages (where they exist) to assist the UI.
    @pagination = Analyzer.new(@enhanced_query, response).pagination if @errors.nil?

    # Display results
    @results = extract_results(response)
    @filters = extract_filters(response)
  end

  private

  def extract_errors(response)
    response&.errors&.details&.to_h&.dig('data')
  end

  def extract_filters(response)
    aggs = response&.data&.search&.to_h&.dig('aggregations')
    return if aggs.blank?

    # We use aggregations to determine which terms can be filtered. However, agg names do not include 'filter', whereas
    # our filter fields do (e.g., 'source' vs 'sourceFilter'). Because of this mismatch, we need to modify the
    # aggregation key names before collecting them as filters, so that when a filter is applied, it searches the
    # correct field name.
    aggs.select { |_, agg_values| agg_values.present? }.transform_keys { |key| (key.dup << 'Filter').to_sym }
  end

  def extract_results(response)
    response&.data&.search&.to_h&.dig('records')
  end

  def validate_q!
    return if params[:advanced]&.strip.present?
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
