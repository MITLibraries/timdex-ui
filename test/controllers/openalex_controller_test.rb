require 'test_helper'

class OpenalexControllerTest < ActionDispatch::IntegrationTest
  test 'openalex route exists with no content' do
    # No cassette because this never results in traffic to OpenAlex
    get '/oa_work'

    assert_response :success
    assert response.body.blank?
  end

  test 'openalex route returns nothing without required parameters' do
    # No cassettes because these never result in traffic to OpenAlex
    # "type" value only
    get '/oa_work?type=doi'

    assert response.body.blank?

    # "identifier" value only
    get '/oa_work?identifier=10.1038/s41567-023-02305-y'

    assert response.body.blank?
  end

  test 'openalex route returns HTML for valid parameters' do
    VCR.use_cassette('openalex doi') do
      get '/oa_work?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_select 'a.button', { count: 1 }
    end
  end

  test 'libkey no response when env var is not set' do
    # No cassette because this never results in traffic to Libkey
    ClimateControl.modify(OPENALEX_EMAIL: nil) do
      get '/oa_work?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert response.body.blank?
    end
  end
end
