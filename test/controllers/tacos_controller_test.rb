require 'test_helper'

class TacosControllerTest < ActionDispatch::IntegrationTest
  test 'analyze route exists' do
    VCR.use_cassette('tacos direct') do
      get '/analyze?q=direct'

      assert_response :success
    end
  end

  test 'tacos with suggested resource' do
    VCR.use_cassette('tacos suggested resource') do
      get '/analyze?q=hours'

      assert_response :success
      assert_includes response.body, 'MIT Libraries Hours'
      assert_includes response.body, 'https://libraries.mit.edu/hours'
    end
  end

  test 'tacos with suggested pattern' do
    VCR.use_cassette('tacos pattern iso') do
      get '/analyze?q=iso 9001'

      assert_response :success
      assert_includes response.body, 'Looking for Standards?'
      assert_includes response.body, 'https://libguides.mit.edu/standards'
    end
  end
end
