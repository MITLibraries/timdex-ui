class RecordController < ApplicationController
  before_action :validate_id!, only: %i[view]

  include RecordHelper

  def view
    id = params[:id]

    timdex = TimdexWrapper.new
    response = timdex.record(id)

    # Detection of unexpected response from the API would go here...

    # Manipulation of returned record would go here...

    @record = response
  end

  private

  def validate_id!
    return if params[:id]&.strip.present?

    flash[:error] = 'A record identifier is required.'
    redirect_to root_url
  end
end
