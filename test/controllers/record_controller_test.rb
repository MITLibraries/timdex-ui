require 'test_helper'

class RecordControllerTest < ActionDispatch::IntegrationTest
  test 'record with no id returns an error' do
    get '/record'
    assert_response :redirect
    assert_equal 'A record identifier is required.', flash[:error]
  end

  test 'full record path with an id does not return an error' do
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/record/jpal:doi:10.7910-DVN-MNIBOL'
      assert_response :success
    end
  end

  test 'record ids can include multiple periods' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex record no record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get "/record/#{needle_id}"
      assert_response :success
    end
  end

  test 'full record display where no record exists displays an error' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex record no record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get "/record/#{needle_id}"
      message = 'Record not found'
      assert_select '#content-main', /(.*)#{message}(.*)/
    end
  end
end
