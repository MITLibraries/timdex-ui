require 'test_helper'

class LibkeyControllerTest < ActionDispatch::IntegrationTest
  test 'lookup route exists with no content' do
    # No cassette because this never results in traffic to Libkey
    get '/lookup'

    assert_response :success
    assert_equal response.body, ''
  end

  test 'lookup route returns nothing without required parameters' do
    # No cassettes because these never result in traffic to Libkey
    # "type" value only
    get '/lookup?type=doi'

    assert_equal response.body, ''

    # "identifier" value only
    get '/lookup?identifier=10.1038/s41567-023-02305-y'

    assert_equal response.body, ''
  end

  test 'lookup route returns HTML for valid parameters' do
    VCR.use_cassette('libkey doi') do
      get '/lookup?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_select 'a.button-primary', { count: 1 }
    end

    VCR.use_cassette('libkey pmid') do
      get '/lookup?type=pmid&identifier=22110403'

      assert_response :success
      assert_select 'a.button-primary', { count: 1 }
    end
  end

  test 'lookup for non-existent identifier returns blank' do
    # Libkey responds here, so we have a cassette - but the response is empty
    VCR.use_cassette('libkey nonexistent') do
      get '/lookup?type=doi&identifier=foobar'

      assert_response :success
      assert_equal response.body, ''
    end
  end

  test 'no response when either env var is not set' do
    # No cassette because this never results in traffic to Libkey
    ClimateControl.modify(LIBKEY_ID: nil) do
      get '/lookup?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_equal response.body, ''
    end

    ClimateControl.modify(LIBKEY_KEY: nil) do
      get '/lookup?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_equal response.body, ''
    end
  end
end
