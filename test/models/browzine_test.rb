require 'test_helper'

class BrowzineMockResponse
  attr_reader :status

  def initialize(status, body)
    @status = status
    @body = body
  end

  def to_s
    @body
  end
end

class BrowzineConnectionError
  def timeout(_)
    self
  end

  def get(_url)
    raise HTTP::ConnectionError, 'forced connection failure'
  end
end

class BrowzineParsingError
  def timeout(_)
    self
  end

  def get(_url)
    BrowzineMockResponse.new(200, 'This is not valid json')
  end
end

class BrowzineInternalError
  def timeout(_)
    self
  end

  def get(_url)
    BrowzineMockResponse.new(500, 'Internal Server Error')
  end
end

class BrowzineTest < ActiveSupport::TestCase
  test 'enabled? method returns true if both env are set' do
    ClimateControl.modify(THIRDIRON_ID: 'foo', THIRDIRON_KEY: 'bar') do
      assert Browzine.enabled?
    end
  end

  test 'enabled? method returns false if either env not set' do
    ClimateControl.modify(THIRDIRON_ID: nil) do
      refute Browzine.enabled?
    end

    ClimateControl.modify(THIRDIRON_KEY: nil) do
      refute Browzine.enabled?
    end
  end

  test 'lookup gets a valid response for issns' do
    VCR.use_cassette('browzine issn') do
      result = Browzine.lookup(issn: '1546170X')

      assert_instance_of Hash, result
      assert_equal result.keys, %i[browzine_link]
    end
  end

  test 'browzine model catches connection errors' do
    browzine_client = BrowzineConnectionError.new

    result = Browzine.lookup(issn: '1546170X', browzine_client:)

    assert_instance_of Hash, result
    assert_equal 'A connection error has occurred', result['error']
  end

  test 'browzine model catches parsing errors' do
    browzine_client = BrowzineParsingError.new

    result = Browzine.lookup(issn: '1546170X', browzine_client:)

    assert_instance_of Hash, result
    assert_equal 'A parsing error has occurred', result['error']
  end

  test 'lookup returns nil for nonexistent issn' do
    VCR.use_cassette('browzine nonexistent') do
      result = Browzine.lookup(issn: '0000000X')

      refute result
    end
  end

  test 'lookup handles connection error' do
    browzine_client = BrowzineConnectionError.new

    result = Browzine.lookup(issn: '1546170X', browzine_client:)

    assert_instance_of Hash, result
    assert_equal 'A connection error has occurred', result['error']
  end

  test 'lookup handles internal server error' do
    browzine_client = BrowzineInternalError.new

    result = Browzine.lookup(issn: '1546170X', browzine_client:)

    assert_nil result
  end
end
