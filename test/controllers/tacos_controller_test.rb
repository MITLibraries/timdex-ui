require 'test_helper'

class TacosControllerTest < ActionDispatch::IntegrationTest
  test 'analyze route exists but returns an HTML comment for now' do
    VCR.use_cassette('tacos direct') do
      get '/analyze?q=direct'

      assert_response :success
      assert_equal "<!-- Result of TACOS analysis would go here -->\n", response.body
    end
  end
end
