require 'test_helper'

class OpenalexMockResponse
  attr_reader :status

  def initialize(status, body)
    @status = status
    @body = body
  end

  def to_s
    @body
  end
end

class OpenalexConnectionError
  def timeout(_)
    self
  end

  def get(_url)
    raise HTTP::ConnectionError, 'forced connection failure'
  end
end

class OpenalexParsingError
  def timeout(_)
    self
  end

  def get(_url)
    OpenalexMockResponse.new(200, 'This is not valid json')
  end
end

class OpenalexTest < ActiveSupport::TestCase
  test 'enabled? method returns true if env is set' do
    ClimateControl.modify(OPENALEX_EMAIL: 'test@example.org') do
      assert Openalex.enabled?
    end
  end

  test 'enabled? method returns false if env not set' do
    ClimateControl.modify(OPENALEX_EMAIL: nil) do
      refute Openalex.enabled?
    end
  end

  test 'work returns nil when not enabled' do
    ClimateControl.modify(OPENALEX_EMAIL: nil) do
      result = Openalex.work(identifier: '10.1038/s41567-023-02305-y')
      assert_nil result
    end
  end

  test 'work gets a valid response for DOIs' do
    VCR.use_cassette('openalex doi') do
      result = Openalex.work(identifier: '10.1038/s41567-023-02305-y')

      assert_instance_of Hash, result
      assert_equal %i[record_id is_open pdf_link html_link type], result.keys
      assert result[:is_open].is_a?(TrueClass)
      assert_not_nil result[:record_id]
      assert_equal 'Published Version', result[:type]
      assert_equal 'https://www.nature.com/articles/s41567-023-02305-y.pdf', result[:pdf_link]
      assert_equal 'http://dx.doi.org/10.1038/s41567-023-02305-y', result[:html_link]
    end
  end

  # Not sure this is an accurate test, leaving for now
  test 'work caches results for 24 hours' do
    VCR.use_cassette('openalex doi') do
      # First call
      result1 = Openalex.work(identifier: '10.1038/s41567-023-02305-y')
      assert_instance_of Hash, result1

      # Second call should return cached result (VCR would error if API called again)
      result2 = Openalex.work(identifier: '10.1038/s41567-023-02305-y')
      assert_equal result1, result2
    end
  end

  test 'work returns nil when no oa_locations available' do
    response = {
      'id' => 'https://openalex.org/W123456789',
      'best_oa_location' => ''
    }

    result = Openalex.extract_metadata(response)

    assert_nil result
  end

  test 'openalex model catches connection errors' do
    openalex_client = OpenalexConnectionError.new

    result = Openalex.work(identifier: '10.1038/s41567-023-02305-y', openalex_client:)

    assert_instance_of Hash, result
    assert_equal 'A connection error has occurred', result['error']
  end

  test 'openalex model catches parsing errors' do
    openalex_client = OpenalexParsingError.new

    result = Openalex.work(identifier: '10.1038/s41567-023-02305-y', openalex_client:)

    assert_instance_of Hash, result
    assert_equal 'A parsing error has occurred', result['error']
  end

  test 'work returns nil when response is blank' do
    openalex_client = mock('openalex_http')
    response_mock = OpenalexMockResponse.new(200, '{}')

    openalex_client.expects(:timeout).with(6).returns(openalex_client)
    openalex_client.expects(:get).returns(response_mock)

    result = Openalex.work(identifier: 'invalid', openalex_client:)
    assert_nil result
  end

  test 'work returns nil when id is missing' do
    openalex_client = mock('openalex_http')
    response_mock = OpenalexMockResponse.new(200, '{"is_open": true, "best_oa_location": "some_url"}')

    openalex_client.expects(:timeout).with(6).returns(openalex_client)
    openalex_client.expects(:get).returns(response_mock)

    result = Openalex.work(identifier: 'invalid', openalex_client:)
    assert_nil result
  end

  test 'work returns nil when OpenAlex returns 404 status' do
    openalex_client = mock('openalex_http')
    response_mock = OpenalexMockResponse.new(404, 'Not Found')

    openalex_client.expects(:timeout).with(6).returns(openalex_client)
    openalex_client.expects(:get).returns(response_mock)

    result = Openalex.work(identifier: 'nonexistent', openalex_client:)
    assert_nil result
  end

  test 'work returns nil when OpenAlex returns unexpected status' do
    openalex_client = mock('openalex_http')
    response_mock = OpenalexMockResponse.new(500, 'Internal Server Error')

    openalex_client.expects(:timeout).with(6).returns(openalex_client)
    openalex_client.expects(:get).returns(response_mock)

    result = Openalex.work(identifier: 'errorcase', openalex_client:)
    assert_nil result
  end

  test 'type_code to user friendly type mapping works' do
    assert_equal 'Accepted Version', Openalex.user_friendly_type('acceptedVersion')
    assert_equal 'Published Version', Openalex.user_friendly_type('publishedVersion')
    assert_equal 'Submitted Version', Openalex.user_friendly_type('submittedVersion')
    assert_equal 'Other', Openalex.user_friendly_type('Other')
  end
end
