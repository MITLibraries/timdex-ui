require 'test_helper'

class RobotsControllerTest < ActionDispatch::IntegrationTest
  test 'robots.txt should disallow everything usually' do
    get '/robots.txt'

    assert_response :success
    assert_includes response.body, "Disallow: /\n"
  end

  test 'robots.txt should disallow only results pages in production' do
    ClimateControl.modify(ROBOTS_ENV: 'production') do
      get '/robots.txt'

      assert_response :success
      assert_includes response.body, "Disallow: /results/\n"
      refute_includes response.body, "Disallow: /\n"
    end
  end
end
