# frozen_string_literal: true

# Queries the Alma SRU endpoint for holdings data
#
# @reference https://developers.exlibrisgroup.com/alma/integrations/SRU/
class AlmaSru
  class LookupFailure < StandardError; end

  class InvalidAlmaId < StandardError; end

  NAMESPACE = { 'holding' => 'http://www.loc.gov/MARC21/slim' }.freeze

  LOCATION_ORDER = {
    'Hayden Library' => 0,
    'Lewis Music Library' => 1,
    'Rotch Library' => 2,
    'Barker Library' => 3,
    'Dewey Library' => 4
  }.freeze

  # lookup is the primary method of interacting with this model.
  #
  # It will receive an Alma ID, validate it, look it up in the Alma SRU, and return a formatted result.
  #
  # It accepts an "alma_client" argument for use when testing, but this is not used in normal operations.
  def self.lookup(raw_identifier, alma_client: nil)
    return [] unless enabled?

    # Validate the raw identifier received. This will raise an InvalidAlmaId if validation fails.
    raise InvalidAlmaId unless valid_alma_id?(raw_identifier)

    # Extract numeric portion from provided raw identifier
    identifier = extract_alma_id(raw_identifier)

    # Build URL
    url = alma_sru_url(identifier)

    # Retrieve that URL
    alma_http = setup(url, alma_client)

    parse_response(alma_http.timeout(6).get(url), identifier)
  rescue InvalidAlmaId
    Rails.logger.debug("Invalid Alma ID: #{raw_identifier}")

    []
  rescue LookupFailure => e
    Rails.logger.debug("Alma lookup failure: #{e}")

    []
  rescue HTTP::Error
    Sentry.capture_message('Alma SRU connection failure')
    Rails.logger.error('Alma SRU connection error')

    []
  end

  # parse_response receives the raw response from the Alma SRU endpoint.
  #
  # For any non-200 response, it raises a LookupFailure.
  #
  # Other responses (in XML format) are parsed by Nokogiri, and we pluck content with an `AVA` tag.
  def self.parse_response(raw_response, reference_identifier)
    raise LookupFailure, raw_response.status unless raw_response.status == 200

    parsed = Nokogiri::XML(raw_response.body.to_s)

    # Confirm that control field 001 matches the identifier we received.
    parsed_controlfield = fetch_controlfield(parsed)
    raise LookupFailure, 'Control field mismatch' unless parsed_controlfield == reference_identifier

    # Look up all AVA tags
    parsed_availabilities = fetch_availabilities(parsed)

    # Format list of entries
    results = parsed_availabilities.map(&method(:format_availability))

    # Reduce list to a single item if multiples exist
    results[0] += ' and other locations' if results.length > 1
    results.first(1)
  end

  # ava_to_hash takes an XML element that represents a single availability record
  # and converts it to a hash. Each code is a key, while its text is the value.
  def self.ava_to_hash(node)
    rebuilt = {}

    node.children.each do |child|
      rebuilt[child.attribute_nodes[0].value] = child.text if child.instance_of?(Nokogiri::XML::Element)
    end

    rebuilt
  end

  # fetch_availabilities receives a parsed XML document (Nokogiri::XML::Document)
  #
  # This document is parsed using xpath to select on the nodes with an tag of AVA,
  # and these are then sorted based on a preferred library order.
  def self.fetch_availabilities(parsed_xml)
    ava_list = parsed_xml.xpath("//holding:datafield[@tag='AVA']", NAMESPACE)

    ava_list
      .map { |el| ava_to_hash(el) }
      .sort_by { |el| [LOCATION_ORDER.fetch(el['q'], 999), el['q'].to_s] }
  end

  # fetch_controlfield receives a parsed XML document (Nokogiri::XML::Document)
  # and returns the controlfield with an 001 tag, if one exists.
  #
  # This allows us to confirm that we've received the expected record back from
  # the API, and not either a blank response or some other unexpected document.
  def self.fetch_controlfield(parsed_xml)
    parsed_xml.xpath("//holding:controlfield[@tag='001']", NAMESPACE)&.text
  end

  # format_availability receives a hash representing a single availability
  # statement, and formats it for human readability. Values for "e" and "q" are
  # required, while "c" and "d" are optional.
  #
  # A Sentry exception is captured if those required parameters are missing.
  def self.format_availability(availability)
    if availability['e'].blank? || availability['q'].blank?
      Sentry.capture_message('Missing required availability data')
      return ''
    end

    phrase = "#{availability['e']&.humanize} at #{availability['q']} #{availability['c']}".squish
    phrase += " (#{availability['d']})" if availability['d'].present?

    phrase
  end

  def self.alma_base_url
    ENV.fetch('MIT_ALMA_URL', nil)
  end

  def self.enabled?
    if alma_base_url.to_s.empty? || exl_inst_id.to_s.empty?
      Sentry.capture_message('Alma SRU not enabled')
      return false
    end

    true
  end

  # extract_alma_id receives a hypothetical document ID that references an alma
  # record, and strips out any `alma` prefix which _may_ exist. This is a
  # compensating strategy for our discovery environment attaching this prefix to
  # flag the record as coming from alma, rather than other collections.
  def self.extract_alma_id(raw)
    if raw.to_s.start_with?('alma')
      raw.to_s.delete_prefix('alma')
    else
      raw.to_s
    end
  end

  # valid_alma_id? receives a document identifier and attempts to determine
  # whether it is a reference to an alma document. This involves using a regular
  # expression to confirm five attributes:
  # 1. The identifier can be converted to a string
  # 2. The identifier may begin with "alma"
  # 3. After any "alma" prefix, the next two characters must be "99"
  # 4. Following this must be a sequence of only digits
  # 5. The identifier must end with "6761"
  #
  # The method returns "true" if all of these conditions are met, otherwise it
  # returns "false". No further action is taken for failing results, as this
  # method is called for a wide range of identifiers.
  def self.valid_alma_id?(raw)
    return false unless raw.present?
    return true if raw.to_s.match?(/\A(alma)?99\d+6761\z/)

    false
  end

  def self.alma_sru_url(identifier)
    # example identifier: 9935177389906761
    "#{alma_base_url}/view/sru/#{exl_inst_id}?version=1.2&operation=searchRetrieve&recordSchema=marcxml" \
      "&query=alma.all_for_ui=#{identifier}"
  end

  def self.exl_inst_id
    ENV.fetch('EXL_INST_ID', nil)
  end

  def self.setup(url, alma_client)
    alma_client || HTTP.persistent(url)
  end
end
