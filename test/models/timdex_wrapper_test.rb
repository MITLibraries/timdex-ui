require 'test_helper'

class TimdexWrapperTest < ActiveSupport::TestCase
  def setup
    ENV['TIMDEX_BASE'] = nil
    ENV['TIMDEX_TIMEOUT'] = nil
  end

  def after
    ENV['TIMDEX_BASE'] = nil
    ENV['TIMDEX_TIMEOUT'] = nil
  end

  test 'timdex url is read from env' do
    # Default value
    needle = 'https://timdex.mit.edu/api/v1/'
    ENV['TIMDEX_BASE'] = nil
    assert_equal(needle, TimdexWrapper.new.send(:timdex_url))

    # Override
    needle = 'https://example.org/'
    ENV['TIMDEX_BASE'] = needle
    assert_equal(needle, TimdexWrapper.new.send(:timdex_url))
  end

  test 'http timeout is controlled by env' do
    # Default value
    needle = 6
    ENV['TIMDEX_TIMEOUT'] = nil
    assert_equal(needle, TimdexWrapper.new.send(:http_timeout))

    needle = 30
    ENV['TIMDEX_TIMEOUT'] = needle.to_s
    assert_equal(needle, TimdexWrapper.new.send(:http_timeout))
  end

  test 'search method returns results' do
    VCR.use_cassette('timdex popcorn',
                     allow_playback_repeats: true) do
      wrapper = TimdexWrapper.new
      result = wrapper.search('popcorn')
      assert_operator(0, :<, result['hits'].to_i)
    end
  end

  test 'quoted searches do not error' do
    VCR.use_cassette('timdex quoted',
                     allow_playback_repeats: true) do
      wrapper = TimdexWrapper.new
      result = wrapper.search('"allegedly"')
      assert_operator(0, :<, result['hits'].to_i)
      refute(result.key?('error'))
    end
  end

  test 'multi-world searches do not error' do
    VCR.use_cassette('timdex multiword',
                     allow_playback_repeats: true) do
      wrapper = TimdexWrapper.new
      result = wrapper.search('carbon nanotubes')
      assert_operator(0, :<, result['hits'].to_i)
      refute(result.key?('error'))
    end
  end

  test 'error handling if timdex does not respond' do
    ENV['TIMDEX_BASE'] = 'https://tiimdex.mit.edu/api/v1/'
    VCR.use_cassette('timdex down',
                     allow_playback_repeats: true) do
      wrapper = TimdexWrapper.new
      result = wrapper.search('timdex is down')
      # Only test that an error is thrown - specifics of how the error is implemented are not relevant now.
      assert(result.key?('error'))
    end
  end

  test 'error handing of 404' do
    ENV['TIMDEX_BASE'] = 'https://timdex.mit.edu/oops/v1/'
    VCR.use_cassette('timdex 404',
                     allow_playback_repeats: true) do
      wrapper = TimdexWrapper.new
      result = wrapper.search('timdex is down')
      # Only test that an error is thrown - specifics of how the error is implemented are not relevant now.
      assert(result.key?('error'))
    end
  end
end
