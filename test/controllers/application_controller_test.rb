require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'the default locale is English' do
    get '/style-guide'
    assert_response :success
    assert_select 'p', text: 'Hello world', count: 1
  end

  test 'locales can be switched' do
    get '/style-guide'
    assert_response :success
    assert_select 'p', text: 'Hello world', count: 1

    get '/ewok/style-guide'
    assert_response :success
    assert_select 'p', text: 'Yub nub', count: 1
  end
end
