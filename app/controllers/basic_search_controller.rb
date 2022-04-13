class BasicSearchController < ApplicationController
  before_action :validate_q!, only: %i[results]

  def index; end

  def results
    timdex = TimdexWrapper.new

    search_string = params[:q]

    # hand off to Enhancer chain
    # For this phase, the Enhancer will just pass the input through as output.

    # hand off enhanced query to builder
    query = QueryBuilder.new(search_string).query

    # builder hands off to wrapper which returns raw results here
    response = timdex.search(query)

    # Analyze results
    # handle errors
    # handle records
    # for now no other analyzing, but at this phase we might later do additional analysis / reordering as we learn more

    # Display stuff
  end

  private

  def validate_q!
    return if params[:q]&.strip.present?

    flash[:error] = 'A search term is required.'
    redirect_to root_url
  end
end
