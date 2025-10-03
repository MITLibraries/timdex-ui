require 'test_helper'

class ErrorResilienceTest < ActionDispatch::IntegrationTest
  # When regenerating cassettes, timdex_error.yml needs to be manually edited so the response status code is 500 and the
  # message is Internal Server Error.
  test 'search results page renders with an error message if the API errors' do
    VCR.use_cassette('timdex error',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=poverty&tab=timdex'
      assert_response :success
      assert_select('.alert', true)
      assert_select('.alert') do |value|
        assert(value.text.include?('500 Internal Server Error'))
      end
    end
  end

  # https://mitlibraries.atlassian.net/browse/TIMX-108
  # https://timdex-ui-pipeline-dev.herokuapp.com/record/alma:9935254980806761
  test 'records without publication dates display without errors' do
    VCR.use_cassette('alma record with no publication date',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/record/alma:9935254980806761'
      assert_response :success
    end
  end
end
