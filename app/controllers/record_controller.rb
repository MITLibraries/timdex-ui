class RecordController < ApplicationController
  before_action :validate_id!, only: %i[view]

  include RecordHelper

  def view
    # If there are formatting requirements for a received ID value, they should be enforced here.
    @id = params[:id]

    timdex = TimdexWrapper.new
    response = timdex.record(@id)

    # Detection of unexpected response from the API would go here...

    # Manipulation of returned record:
    # The API includes three housekeeping fields which are not part of the record.
    %w[request_limit request_count limit_info].each do |value|
      response.delete(value)
    end

    @record = response
  end

  private

  def validate_id!
    return if params[:id]&.strip.present?

    flash[:error] = 'A record identifier is required.'
    redirect_to root_url
  end
end
