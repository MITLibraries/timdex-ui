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

  # Converts a bounding box into a top left, bottom right set of coordinates
  def bounding_box_to_coords
    return unless @record.present?
    return unless geospatial_coordinates?(@record['locations'])

    # Our preference is to use the `Bounding Box` kind
    raw_bbox = @record['locations'].select { |l| l if l['kind'] == 'Bounding Box' }.first

    # If we had no `Bounding Box` kind, see if we have a `Geometry kind`
    if raw_bbox.blank?
      raw_bbox = @record['locations'].select { |l| l if l['kind'] == 'Geometry' }.first
    end

    return unless raw_bbox.present?

    # extract just the geo coordinates and remove the extra syntax
    bbox = raw_bbox['geoshape'].sub('BBOX (', '').sub(')', '')

    # conver the string into an array of floats
    bbox_array = bbox.split(',').map!(&:strip).map!(&:to_f)

    # Protect against unexpected data
    if bbox_array.count != 4
      Rails.logger.info("Unexpected Bounding Box: #{raw_bbox}")
      return
    end

    coords = [[bbox_array[2], bbox_array[0]], [bbox_array[3], bbox_array[1]]]
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
