class BasicSearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  def index; end

  def results
    # hand off to Enhancer chain
    @enhanced_query = Enhancer.new(params).enhanced_query

    # hand off enhanced query to builder
    query = QueryBuilder.new(@enhanced_query).query

    # builder hands off to wrapper which returns raw results here
    response = Timdex::Client.query(Timdex::SearchQuery, variables: query)

    # Analyze results
    # handle errors
    @errors = response&.errors&.details&.to_h&.dig('data')

    # handle records
    # for now no other analyzing, but at this phase we might later do additional analysis / reordering as we learn more
    hits = response&.data&.search&.to_h&.dig('hits')
    @results = response&.data&.search&.to_h&.dig('records')

    # Display stuff
    @pagy, = pagy_array(@results, count: hits)
    @facets = response&.data&.search&.to_h&.dig('aggregations')
  end

  private

  def validate_q!
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
