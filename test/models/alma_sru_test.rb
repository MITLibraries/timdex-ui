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

      assert_equal(
        ["<i class='fa-sharp fa-solid fa-check' aria-hidden='true'></i> Available in <strong>Rotch Library</strong> Stacks (NA680.C25 2007)"],
        result[:availability]
      )
      assert_equal false, result[:alma_e]
    end
  end

  test 'lookup returns a single entry, prioritizing self-service locations first, if multiples exist' do
    VCR.use_cassette('alma sru multiple records') do
      needle = '990002935920106761'

      result = AlmaSru.lookup(needle)

      assert_equal(1, result[:availability].length)
      assert_includes result[:availability][0], 'and other locations'
      assert_equal false, result[:alma_e]
    end
  end

  test 'lookup returns empty availability if no AVA' do
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'

      result = AlmaSru.lookup(needle)

      assert_equal([], result[:availability])
    end
  end

  test 'lookup returns true Alma-E if AVE is present' do
    # This cassette was generated to demonstrate a record with no AVA, but it has an AVE
    VCR.use_cassette('alma sru no availability') do
      needle = 'alma9935053423706761'

      result = AlmaSru.lookup(needle)

      assert_equal true, result[:alma_e]
    end
  end

  test 'lookup returns false Alma-E when AVE is absent' do
    VCR.use_cassette('alma sru single record') do
      needle = 'alma990014651640106761'

      result = AlmaSru.lookup(needle)

      assert_equal false, result[:alma_e]
    end
  end

  test 'alma_e? returns true when AVE is absent but 959 subfield b is NET' do
    xml_content = <<~XML
      <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <records>
          <record>
            <recordData>
              <record xmlns="http://www.loc.gov/MARC21/slim">
                <controlfield tag="001">990027661060106761</controlfield>
                <datafield tag="959" ind1=" " ind2="1">
                  <subfield code="1">MIT Access Only</subfield>
                  <subfield code="a">n-mit</subfield>
                  <subfield code="b">NET</subfield>
                  <subfield code="h">**See URL(s)</subfield>
                </datafield>
              </record>
            </recordData>
          </record>
        </records>
      </searchRetrieveResponse>
    XML

    parsed = Nokogiri::XML(xml_content)
    assert_equal true, AlmaSru.alma_e?(parsed)
  end

  test 'alma_e? returns false when AVE is absent and 959 subfield b is not NET' do
    xml_content = <<~XML
      <searchRetrieveResponse xmlns="http://www.loc.gov/zing/srw/">
        <records>
          <record>
            <recordData>
              <record xmlns="http://www.loc.gov/MARC21/slim">
                <controlfield tag="001">990002941700106761</controlfield>
                <datafield tag="959" ind1=" " ind2=" ">
                  <subfield code="b">LSA</subfield>
                  <subfield code="c">JRNAL</subfield>
                </datafield>
              </record>
            </recordData>
          </record>
        </records>
      </searchRetrieveResponse>
    XML

    parsed = Nokogiri::XML(xml_content)
    assert_equal false, AlmaSru.alma_e?(parsed)
  end

  test 'lookup returns empty list for non-existent records' do
    VCR.use_cassette('alma sru nonexistent record') do
      needle = 'alma9900000000006761'

      result = AlmaSru.lookup(needle)

      assert_equal([], result[:availability])
      assert_equal false, result[:alma_e]
    end
  end

  test 'lookup returns empty availability if alma URL not set' do
    needle = 'alma990014651640106761'

    VCR.use_cassette('alma sru single record') do
      result = AlmaSru.lookup(needle)
      assert_equal(1, result[:availability].length)
    end

    ClimateControl.modify(MIT_ALMA_URL: nil) do
      result = AlmaSru.lookup(needle)
      assert_equal({ availability: [], alma_e: false }, result)
    end
  end

  test 'lookup returns empty availability if exl_inst_id not set' do
    needle = 'alma990014651640106761'

    VCR.use_cassette('alma sru single record') do
      result = AlmaSru.lookup(needle)
      assert_equal(1, result[:availability].length)
    end

    ClimateControl.modify(EXL_INST_ID: nil) do
      AlmaSru.remove_instance_variable(:@enabled)

      result = AlmaSru.lookup(needle)
      assert_equal({ availability: [], alma_e: false }, result)
    end
  end

  test 'lookup returns empty hash for non-complying ID' do
    needle = 'foo'

    result = AlmaSru.lookup(needle)

    assert_equal({ availability: [], alma_e: false }, result)
  end

  test 'lookup returns empty hash with empty string' do
    needle = ''

    result = AlmaSru.lookup(needle)

    assert_equal({ availability: [], alma_e: false }, result)
  end

  test 'lookup returns empty hash with nil input' do
    needle = nil

    result = AlmaSru.lookup(needle)

    assert_equal({ availability: [], alma_e: false }, result)
  end

  test 'lookup survives failing to connect to Alma SRU' do
    alma_client = AlmaConnectionError.new

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal({ availability: [], alma_e: false }, result)
    end
  end

  test 'lookup survives Alma SRU errors' do
    alma_client = AlmaErrorResponse.new

    needle = 'alma990014651640106761'

    assert_nothing_raised do
      result = AlmaSru.lookup(needle, alma_client: alma_client)

      assert_equal({ availability: [], alma_e: false }, result)
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
      'e' => 'available',
      'q' => 'quebec'
    }

    assert_equal(
      "<i class='fa-sharp fa-solid fa-check' aria-hidden='true'></i> Available in <strong>quebec</strong> charlie (delta)",
      AlmaSru.format_availability(ava_hash)
    )
  end

  test 'format_availability returns a minimum statement if only e and q are present' do
    ava_hash = {
      'e' => 'available',
      'q' => 'quebec'
    }

    assert_equal("<i class='fa-sharp fa-solid fa-check' aria-hidden='true'></i> Available in <strong>quebec</strong>",
                 AlmaSru.format_availability(ava_hash))
  end

  test 'format_availability supports check_holdings status' do
    ava_hash = {
      'e' => 'check_holdings',
      'q' => 'quebec'
    }

    assert_equal(
      "<i class='fa-sharp fa-solid fa-question' aria-hidden='true'></i> May be available in <strong>quebec</strong>",
      AlmaSru.format_availability(ava_hash)
    )
  end

  test 'format_availability supports unavailable status' do
    ava_hash = {
      'e' => 'unavailable',
      'q' => 'quebec'
    }

    assert_equal(
      "<i class='fa-sharp fa-solid fa-times' aria-hidden='true'></i> Not currently available in <strong>quebec</strong>",
      AlmaSru.format_availability(ava_hash)
    )
  end

  test 'format_availability does not fail with unexpected status' do
    ava_hash = {
      'e' => 'echo',
      'q' => 'quebec'
    }

    assert_equal(
      "<i class='fa-sharp fa-solid fa-question' aria-hidden='true'></i> Uncertain availability (Echo) in <strong>quebec</strong>",
      AlmaSru.format_availability(ava_hash)
    )
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
