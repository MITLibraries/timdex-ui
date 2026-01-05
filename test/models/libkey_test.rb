require 'test_helper'

class LibkeyMockResponse
  attr_reader :status

  def initialize(status, body)
    @status = status
    @body = body
  end

  def to_s
    @body
  end
end

class LibkeyConnectionError
  def timeout(_)
    self
  end

  def get(_url)
    raise HTTP::ConnectionError, 'forced connection failure'
  end
end

class LibkeyParsingError
  def timeout(_)
    self
  end

  def get(_url)
    LibkeyMockResponse.new(200, 'This is not valid json')
  end
end

class LibkeyTest < ActiveSupport::TestCase
  test 'enabled? method returns true if both env are set' do
    ClimateControl.modify(LIBKEY_ID: 'foo', LIBKEY_KEY: 'bar') do
      assert Libkey.enabled?
    end
  end

  test 'enabled? method returns false if either env not set' do
    ClimateControl.modify(LIBKEY_ID: nil) do
      refute Libkey.enabled?
    end

    ClimateControl.modify(LIBKEY_KEY: nil) do
      refute Libkey.enabled?
    end
  end

  test 'lookup does nothing with a type other than "doi" or "pmid"' do
    refute Libkey.lookup(type: 'foo', identifier: 'foobar')
  end

  test 'lookup does work with any identifier value' do
    VCR.use_cassette('libkey nonexistent') do
      result = Libkey.lookup(type: 'doi', identifier: 'foobar')

      refute result
    end
  end

  test 'lookup gets a valid response for DOIs' do
    VCR.use_cassette('libkey doi') do
      result = Libkey.lookup(type: 'doi', identifier: '10.1038/s41567-023-02305-y')

      assert_instance_of Hash, result
      assert_equal result.keys, %i[best_integrator_link browzine_link html_link pdf_link openurl_link]
    end
  end

  test 'lookup gets a valid response for PMIDs' do
    VCR.use_cassette('libkey pmid') do
      result = Libkey.lookup(type: 'pmid', identifier: '22110403')

      assert_instance_of Hash, result
      assert_equal result.keys, %i[best_integrator_link browzine_link html_link pdf_link openurl_link]
    end
  end

  test 'libkey model catches connection errors' do
    libkey_client = LibkeyConnectionError.new

    result = Libkey.lookup(type: 'doi', identifier: '10.1038/s41567-023-02305-y', libkey_client:)

    assert_instance_of Hash, result
    assert_equal 'A connection error has occurred', result['error']
  end

  test 'libkey model catches parsing errors' do
    libkey_client = LibkeyParsingError.new

    result = Libkey.lookup(type: 'doi', identifier: '10.1038/s41567-023-02305-y', libkey_client:)

    assert_instance_of Hash, result
    assert_equal 'A parsing error has occurred', result['error']
  end
end
