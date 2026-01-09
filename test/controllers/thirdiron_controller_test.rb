require 'test_helper'

class ThirdironControllerTest < ActionDispatch::IntegrationTest
  test 'libkey route exists with no content' do
    # No cassette because this never results in traffic to Libkey
    get '/libkey'

    assert_response :success
    assert_equal response.body, ''
  end

  test 'libkey route returns nothing without required parameters' do
    # No cassettes because these never result in traffic to Libkey
    # "type" value only
    get '/libkey?type=doi'

    assert_equal response.body, ''

    # "identifier" value only
    get '/libkey?identifier=10.1038/s41567-023-02305-y'

    assert_equal response.body, ''
  end

  test 'libkey route returns HTML for valid parameters' do
    VCR.use_cassette('libkey doi') do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_select 'a.button', { count: 3 }
    end

    VCR.use_cassette('libkey pmid') do
      get '/libkey?type=pmid&identifier=22110403'

      assert_response :success
      assert_select 'a.button', { count: 3 }
    end
  end

  test 'libkey for non-existent identifier returns blank' do
    # Libkey responds here, so we have a cassette - but the response is empty
    VCR.use_cassette('libkey nonexistent') do
      get '/libkey?type=doi&identifier=foobar'

      assert_response :success
      assert_equal response.body, ''
    end
  end

  test 'libkey no response when either env var is not set' do
    # No cassette because this never results in traffic to Libkey
    ClimateControl.modify(LIBKEY_ID: nil) do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_equal response.body, ''
    end

    ClimateControl.modify(LIBKEY_KEY: nil) do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_equal response.body, ''
    end
  end
end
