require 'test_helper'

class TimdexWrapperTest < ActiveSupport::TestCase
  def basic_query
    {
      'q' => 'data',
      'page' => 1,
      'full' => false
    }
  end

  test 'timdex url is read from env' do
    # Default value
    needle = 'https://timdex.mit.edu/api/v1/'
    ClimateControl.modify(
      TIMDEX_BASE: nil
    ) do
      assert_equal(needle, TimdexWrapper.new.send(:timdex_url))
    end

    # Override
    needle = 'https://example.org/'
    ClimateControl.modify(
      TIMDEX_BASE: needle
    ) do
      assert_equal(needle, TimdexWrapper.new.send(:timdex_url))
    end
  end

  test 'http timeout is controlled by env' do
    # Default value
    needle = 6
    ClimateControl.modify(
      TIMDEX_TIMEOUT: nil
    ) do
      assert_equal(needle, TimdexWrapper.new.send(:http_timeout))
    end

    needle = 30
    ClimateControl.modify(
      TIMDEX_TIMEOUT: needle.to_s
    ) do
      assert_equal(needle, TimdexWrapper.new.send(:http_timeout))
    end
  end

  test 'search method returns results' do
    VCR.use_cassette('data',
                     allow_playback_repeats: true) do
      query = basic_query
      wrapper = TimdexWrapper.new
      result = wrapper.search(query)
      refute(result.key?('error'))
      assert_operator(0, :<, result['hits']['value'].to_i)
    end
  end

  test 'quoted searches do not error' do
    VCR.use_cassette('timdex quoted',
                     allow_playback_repeats: true) do
      query = basic_query
      query['q'] = "'Subsidies'"
      wrapper = TimdexWrapper.new
      result = wrapper.search(query)
      refute(result.key?('error'))
      assert_operator(0, :<, result['hits']['value'].to_i)
    end
  end

  test 'multi-world searches do not error' do
    VCR.use_cassette('timdex multiword',
                     allow_playback_repeats: true) do
      query = basic_query
      query['q'] = 'persistent power'
      wrapper = TimdexWrapper.new
      result = wrapper.search(query)
      refute(result.key?('error'))
      assert_operator(0, :<, result['hits']['value'].to_i)
    end
  end

  test 'error handling if timdex does not respond' do
    skip 'this is not actually using a cassette so it is attempting a real http call. we need to fix before activating'
    ClimateControl.modify(
      TIMDEX_BASE: 'http://localhost:9999/api/v1/'
    ) do
      VCR.use_cassette('timdex down',
                       allow_playback_repeats: true) do
        query = basic_query
        wrapper = TimdexWrapper.new
        result = wrapper.search(query)
        # Only test that an error is thrown - specifics of how the error is implemented are not relevant now.
        assert(result.key?('error'))
      end
    end
  end

  test 'error handing of 404' do
    ClimateControl.modify(
      TIMDEX_BASE: 'https://timdex.mit.edu/oops/v1/'
    ) do
      VCR.use_cassette('timdex 404',
                       allow_playback_repeats: true) do
        query = basic_query
        wrapper = TimdexWrapper.new
        result = wrapper.search(query)
        # Only test that an error is thrown - specifics of how the error is implemented are not relevant now.
        assert(result.key?('error'))
      end
    end
  end
end
