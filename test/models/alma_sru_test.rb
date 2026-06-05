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
  test 'lookup returns text for successful lookup' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'

      result = AlmaSru.lookup(needle)

      assert_equal(result, ['Available at Rotch Library Stacks (NA680.C25 2007)'])
    end
  end

  test 'lookup returns self-service locations first if multiples exist' do
    VCR.use_cassette('alma sru multiple records') do
      needle = '990002935920106761'

      result = AlmaSru.lookup(needle)

      assert_equal(result[0], 'Check holdings at Barker Library Staff Retrieval - request required (FICHE No Call #)')
      assert_equal(result[1], 'Available at Library Storage Annex Journal Collection (LSA4) (TA.J86.H437)')
    end
  end

  test 'lookup returns empty list if no availability' do
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'

      result = AlmaSru.lookup(needle)

      assert_equal(result, [])
    end
  end

  test 'lookup returns empty list for non-existent records' do
    output = StringIO.new
    Rails.logger = Logger.new(output)

    VCR.use_cassette('alma sru nonexistent record') do
      needle = 'alma9900000000006761'

      result = AlmaSru.lookup(needle)

      assert_equal(result, [])

      # This condition gets logged for local investigation due to control field mismatch
      assert_match('Alma lookup failure: Control field mismatch', output.string)
    end
  end

  test 'lookup returns nil if env not set' do
    needle = '990002935920106761'
    ClimateControl.modify(MIT_ALMA_URL: nil) do
      assert_equal([], AlmaSru.lookup(needle))
    end
  end

  test 'lookup returns nil with non-complying ID' do
    needle = 'foo'

    result = AlmaSru.lookup(needle)

    assert_equal([], result)
  end

  test 'lookup survives failing to connect to Alma SRU' do
    alma_client = AlmaConnectionError.new
    output = StringIO.new
    Rails.logger = Logger.new(output)

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal([], result)

      # This condition gets logged for local investigation
      assert_match('Alma SRU connection error', output.string)
    end
  end

  test 'lookup survives Alma SRU errors' do
    alma_client = AlmaErrorResponse.new
    output = StringIO.new
    Rails.logger = Logger.new(output)

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal(result, [])

      # This condition gets logged for local investigation
      assert_match('Alma lookup failure: 500', output.string)
    end
  end

  test 'validate_alma_id succeeds with valid numeric input' do
    needle = '990002935920106761'
    assert_nothing_raised do
      AlmaSru.validate_alma_id(needle)
    end
  end

  test 'validate_alma_id succeeds despite an "alma" prefix' do
    needle = 'alma990002935920106761'
    assert_nothing_raised do
      AlmaSru.validate_alma_id(needle)
    end
  end

  test 'validate_alma_id raises InvalidAlmaId without required start sequence' do
    assert_raises(AlmaSru::InvalidAlmaId) do
      AlmaSru.validate_alma_id('0002935920106761')
    end

    assert_raises(AlmaSru::InvalidAlmaId) do
      AlmaSru.validate_alma_id('alma0002935920106761')
    end
  end

  test 'validate_alma_id raises InvalidAlmaId without required end sequence' do
    assert_raises(AlmaSru::InvalidAlmaId) do
      AlmaSru.validate_alma_id('99000293592010')
    end

    assert_raises(AlmaSru::InvalidAlmaId) do
      AlmaSru.validate_alma_id('alma99000293592010')
    end
  end

  test 'validate_alma_id raises InvalidAlmaId with wildly invalid input' do
    assert_raises(AlmaSru::InvalidAlmaId) do
      AlmaSru.validate_alma_id('foo')
    end
  end

  test 'fetch_controlfield isolates the controlfield with tag 001' do
    needle = '990002935920106761'

    xml_content = File.read('test/fixtures/alma/sru_success.xml')
    parsed = Nokogiri::XML(xml_content)
    result = AlmaSru.fetch_controlfield(parsed)

    assert_equal(result, needle)
  end

  test 'fetch_controlfield returns empty string if controlfield not found' do
    xml_content = File.read('test/fixtures/alma/sru_nocontrol.xml')
    parsed = Nokogiri::XML(xml_content)
    result = AlmaSru.fetch_controlfield(parsed)

    assert_equal(result, '')
  end

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

  test 'format_availability returns availability in pattern of "E q c (d)"' do
    ava_hash = {
      'c' => 'charlie',
      'd' => 'delta',
      'e' => 'echo',
      'q' => 'quebec'
    }

    assert_equal('Echo at quebec charlie (delta)', AlmaSru.format_availability(ava_hash))
  end

  # Is this the behavior we want?
  test 'format_availability does not error with missing fields' do
    ava_hash = {
      'b' => 'beta'
    }

    assert_equal(' at   ()', AlmaSru.format_availability(ava_hash))
  end
end
