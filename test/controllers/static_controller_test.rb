require 'test_helper'

class StaticControllerTest < ActionDispatch::IntegrationTest
  test 'about natural language search page returns success' do
    get about_natural_language_search_path

    assert_response :success
  end

  test 'style guide page returns success' do
    get style_guide_path

    assert_response :success
  end
end
