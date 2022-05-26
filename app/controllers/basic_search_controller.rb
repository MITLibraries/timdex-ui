class BasicSearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  def index; end

  def results
    # hand off to Enhancer chain
    @enhanced_query = Enhancer.new(params).enhanced_query

    # hand off enhanced query to builder
    query = QueryBuilder.new(@enhanced_query).query

    # builder hands off to wrapper which returns raw results here
    response = TimdexBase::Client.query(TimdexSearch::Query, variables: query)

    # Analyze results
    # handle errors
    @errors = response&.errors&.details&.to_h&.dig('data')

    # handle records
    # for now no other analyzing, but at this phase we might later do additional analysis / reordering as we learn more
    @pagination = Analyzer.new(@enhanced_query, response).pagination if @errors.nil?

    # Display stuff
    @results = response&.data&.search&.to_h&.dig('records')
    @facets = response&.data&.search&.to_h&.dig('aggregations')
  end

  private

  def validate_q!
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
