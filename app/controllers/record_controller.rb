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
    @rectangle = bounding_box_to_coords
  end

  private

  def bounding_box_to_coords
    return unless geospatial_coordinates?(@record['locations'])

    raw_bbox = @record['locations'].select { |l| l if l['kind'] == 'Bounding Box' }.first
    bbox = raw_bbox['geoshape'].sub('BBOX (', '').sub(')', '')
    bbox_array = bbox.split(', ')
    coords = [[bbox_array[2].to_f, bbox_array[0].to_f], [bbox_array[3].to_f, bbox_array[1].to_f]]
    Rails.logger.info("Raw BBox: #{raw_bbox}")
    Rails.logger.info("Rectangle: #{coords}")
    coords
  end

  def validate_id!
    return if params[:id]&.strip.present?

    flash[:error] = 'A record identifier is required.'
    redirect_to root_url
  end
end
