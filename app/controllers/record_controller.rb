class RecordController < ApplicationController
  before_action :validate_id!, only: %i[view]

  include RecordHelper

  def view
    id = params[:id]
    index = ENV.fetch('TIMDEX_INDEX', nil)

    response = TimdexBase::Client.query(TimdexRecord::Query, variables: { id:, index: })

    # Detection of unexpected response from the API would go here...

    @errors = response&.errors&.details&.to_h&.dig('data')

    # Manipulation of returned record would go here...

    @record = response&.data&.to_h&.dig('recordId')
  end

  private

  def validate_id!
    return if params[:id]&.strip.present?

    flash[:error] = 'A record identifier is required.'
    redirect_to root_url
  end
end
