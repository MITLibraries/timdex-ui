require 'test_helper'

class RecordControllerTest < ActionDispatch::IntegrationTest
  test 'record with no id returns an error' do
    get '/record'
    assert_response :redirect
    assert_equal 'A record identifier is required.', flash[:error]
  end

  test 'full record path with an id does not return an error' do
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true) do
      get '/record/jpal:doi:10.7910-DVN-MNIBOL'
      assert_response :success
    end
  end

  test 'record ids can include multiple periods' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex record no record',
                     allow_playback_repeats: true) do
      get "/record/#{needle_id}"
      assert_response :success
    end
  end

  test 'full record display includes the record id itself' do
    needle_id = 'jpal:doi:10.7910-DVN-MNIBOL'
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true) do
      get "/record/#{needle_id}"
      assert_select 'p.id', /(.*)#{needle_id}(.*)/
    end
  end

  test 'full record display where no record exists displays an error' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex record no record',
                     allow_playback_repeats: true) do
      get "/record/#{needle_id}"
      message = 'record not found'
      assert_select 'div.record', /(.*)#{message}(.*)/
    end
  end

  test 'full record display does not include housekeeping fields' do
    needle_id = 'jpal:doi:10.7910-DVN-MNIBOL'
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true) do
      get "/record/#{needle_id}"
      assert_select 'div.record', { count: 0, text: /(.*)'request_limit'(.*)/ }
      assert_select 'div.record', { count: 0, text: /(.*)'request_count'(.*)/ }
      assert_select 'div.record', { count: 0, text: /(.*)'limit_info'(.*)/ }
    end
  end
end
