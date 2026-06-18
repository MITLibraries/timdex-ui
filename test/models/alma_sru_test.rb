require 'test_helper'

class AlmaSruMockResponse
  attr_reader :status

  def initialize(status, body)
    @status = status
    @body = body
  end

  def to_s
    @body
  end
end

class AlmaConnectionError
  def timeout(_)
    self
  end

  def get(_url)
    raise HTTP::ConnectionError, 'forced connection failure'
  end
end

class AlmaErrorResponse
  def timeout(_)
    self
  end

  def get(_url)
    AlmaSruMockResponse.new(500, 'internal server error')
  end
end

class AlmaSruTest < ActiveSupport::TestCase
  # Lookup method
  test 'lookup returns text for successful lookup' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'

      result = AlmaSru.lookup(needle)

      assert_equal(['Available at Rotch Library Stacks (NA680.C25 2007)'], result)
    end
  end

  test 'lookup returns a single entry, prioritizing self-service locations first, if multiples exist' do
    VCR.use_cassette('alma sru multiple records') do
      needle = '990002935920106761'

      result = AlmaSru.lookup(needle)

      assert_equal(1, result.length)
      assert_equal(
        'Check holdings at Barker Library Staff Retrieval - request required (FICHE No Call #) and other locations',
        result[0]
      )
    end
  end

  test 'lookup returns empty list if no availability' do
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'

      result = AlmaSru.lookup(needle)

      assert_equal([], result)
    end
  end

  test 'lookup returns empty list for non-existent records' do
    VCR.use_cassette('alma sru nonexistent record') do
      needle = 'alma9900000000006761'

      result = AlmaSru.lookup(needle)

      assert_equal([], result)
    end
  end

  test 'lookup returns empty list if alma URL not set' do
    needle = 'alma990014651640106761'

    VCR.use_cassette('alma sru single record') do
      assert_equal(1, AlmaSru.lookup(needle).length)
    end

    ClimateControl.modify(MIT_ALMA_URL: nil) do
      assert_equal([], AlmaSru.lookup(needle))
    end
  end

  test 'lookup returns empty list if exl_inst_id not set' do
    needle = 'alma990014651640106761'

    VCR.use_cassette('alma sru single record') do
      assert_equal(1, AlmaSru.lookup(needle).length)
    end

    ClimateControl.modify(EXL_INST_ID: nil) do
      assert_equal([], AlmaSru.lookup(needle))
    end
  end

  test 'lookup returns empty list with non-complying ID' do
    needle = 'foo'

    result = AlmaSru.lookup(needle)

    assert_equal([], result)
  end

  test 'lookup returns empty list with empty string' do
    needle = ''

    result = AlmaSru.lookup(needle)

    assert_equal([], result)
  end

  test 'lookup returns empty list with nil input' do
    needle = nil

    result = AlmaSru.lookup(needle)

    assert_equal([], result)
  end

  test 'lookup survives failing to connect to Alma SRU' do
    alma_client = AlmaConnectionError.new

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal([], result)
    end
  end

  test 'lookup survives Alma SRU errors' do
    alma_client = AlmaErrorResponse.new

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal([], result)
    end
  end

  # valid_alma_id? method
  test 'valid_alma_id? returns true for valid inputs' do
    # rubocop:disable Style/NumericLiterals
    needles = [
      990002935920106761,
      '990002935920106761',
      'alma990002935920106761'
    ]
    # rubocop:enable Style/NumericLiterals

    needles.each do |needle|
      assert_equal(true, AlmaSru.valid_alma_id?(needle))
    end
  end

  test 'valid_alma_id? returns false for invalid inputs' do
    needles = [
      nil,
      'cdi_econis_primary_1902984668',   # wildly nonconforming
      '99000293foo5920106761',           # non-numeric internals
      '0002935920106761',                # missing start sequence
      'alma0002935920106761',            # missing start sequence
      '99000293592010',                  # missing end sequence
      'alma99000293592010'               # missing end sequence
    ]

    needles.each do |needle|
      assert_equal(false, AlmaSru.valid_alma_id?(needle))
    end
  end

  # fetch_controlfield method
  test 'fetch_controlfield isolates the controlfield with tag 001' do
    needle = '990002935920106761'

    xml_content = File.read('test/fixtures/alma/sru_success.xml')
    parsed = Nokogiri::XML(xml_content)
    result = AlmaSru.fetch_controlfield(parsed)

    assert_equal(needle, result)
  end

  test 'fetch_controlfield returns empty string if controlfield not found' do
    xml_content = File.read('test/fixtures/alma/sru_nocontrol.xml')
    parsed = Nokogiri::XML(xml_content)
    result = AlmaSru.fetch_controlfield(parsed)

    assert_equal('', result)
  end

  # fetch_availabilities method
  test 'fetch_availabilities will list some libraries first' do
    needle_first = 'Library Storage Annex'
    needle_second = 'Barker Library'

    xml_content = File.read('test/fixtures/alma/sru_wrong_order.xml')
    parsed = Nokogiri::XML(xml_content)

    raw_first = parsed.at_xpath("(//holding:datafield[@tag='AVA'])[1]/holding:subfield[@code='q']/text()", AlmaSru::NAMESPACE)&.text
    raw_second = parsed.at_xpath("(//holding:datafield[@tag='AVA'])[2]/holding:subfield[@code='q']/text()", AlmaSru::NAMESPACE)&.text

    assert_equal(needle_first, raw_first)
    assert_equal(needle_second, raw_second)

    result = AlmaSru.fetch_availabilities(parsed)

    assert_equal(needle_second, result[0]['q'])
    assert_equal(needle_first, result[1]['q'])
  end

  # format_availability method
  test 'format_availability returns availability in pattern of "E q c (d)"' do
    ava_hash = {
      'c' => 'charlie',
      'd' => 'delta',
      'e' => 'echo',
      'q' => 'quebec'
    }

    assert_equal('Echo at quebec charlie (delta)', AlmaSru.format_availability(ava_hash))
  end

  test 'format_availability returns a minimum statement if only e and q are present' do
    ava_hash = {
      'e' => 'echo',
      'q' => 'quebec'
    }

    assert_equal('Echo at quebec', AlmaSru.format_availability(ava_hash))
  end

  test 'format_availability returns an empty string without both e and q present' do
    ava_hash = {
      'b' => 'beta'
    }

    assert_equal('', AlmaSru.format_availability(ava_hash))

    ava_hash = {
      'e' => 'echo'
    }

    assert_equal('', AlmaSru.format_availability(ava_hash))
    ava_hash = {
      'q' => 'quebec'
    }

    assert_equal('', AlmaSru.format_availability(ava_hash))
  end
end
