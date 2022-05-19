class BasicSearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  def index; end

  def results
    # hand off to Enhancer chain
    @enhanced_query = Enhancer.new(params).enhanced_query

    # hand off enhanced query to builder
    query = QueryBuilder.new(@enhanced_query).query

    # builder hands off to wrapper which returns raw results here
    # BEGIN EDITORIALIZING
    # The following works in a console:
    #
    # $ query = {'q' => 'data'}
    # $ wrapper = TimdexCandy.new
    # $ Parsed = wrapper.client.parse(TimdexCandy::SearchQueryText)
    # $ Parsed.class # Debugging to make sure this worked
    # => GraphQL::Client::OperationDefinition
    # $ wrapper.search(Parsed, query)
    # => #<GraphQL::Client::Response:0x00000001155c0dd0 ...
    #
    # However, this parsing of the search query text is not working here in the controller.
    # The parsed query needs to be a constant, or the library fails with a 'expected definition to be assigned to a
    # static constant' error - with the URL https://git.io/vXXSE as explanation.
    #
    wrapper = TimdexCandy.new
    response = wrapper.search(wrapper.client.parse(TimdexCandy::SearchQueryText), query)

    # Analyze results
    # handle errors
    @errors = response&.errors&.details['data']

    # handle records
    # for now no other analyzing, but at this phase we might later do additional analysis / reordering as we learn more

    # Display stuff
    @results = response&.data&.search&.to_h['records']
    @facets = response&.data&.search&.to_h['aggregations']
  end

  private

  def validate_q!
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
