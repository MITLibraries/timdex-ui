class BasicSearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  def index; end

  def results
    # hand off to Enhancer chain
    @enhanced_query = Enhancer.new(params).enhanced_query

    # hand off enhanced query to builder
    query = QueryBuilder.new(@enhanced_query).query

    # builder hands off to wrapper which returns raw results here
    timdex = TimdexWrapper.new
    response = timdex.search(query)

    # Analyze results
    # handle errors
    # handle records
    # for now no other analyzing, but at this phase we might later do additional analysis / reordering as we learn more

    # Display stuff
    @results = response['results']
    @facets = response['aggregations']
  end

  private

  def validate_q!
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
