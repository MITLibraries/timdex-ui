require 'test_helper'

class ThirdironControllerTest < ActionDispatch::IntegrationTest
  test 'libkey route exists with no content' do
    # No cassette because this never results in traffic to Libkey
    get '/libkey'

    assert_response :success
    assert response.body.blank?
  end

  test 'libkey route returns nothing without required parameters' do
    # No cassettes because these never result in traffic to Libkey
    # "type" value only
    get '/libkey?type=doi'

    assert response.body.blank?

    # "identifier" value only
    get '/libkey?identifier=10.1038/s41567-023-02305-y'

    assert response.body.blank?
  end

  test 'libkey route returns HTML for valid parameters' do
    VCR.use_cassette('libkey doi') do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert_select 'a.libkey-link', { count: 3 }
    end

    VCR.use_cassette('libkey pmid') do
      get '/libkey?type=pmid&identifier=22110403'

      assert_response :success
      assert_select 'a.libkey-link', { count: 3 }
    end
  end

  test 'libkey for non-existent identifier inserts openalex setup when oa_always is false' do
    # Libkey responds here, so we have a cassette - but the response is empty
    VCR.use_cassette('libkey nonexistent') do
      get '/libkey?type=doi&identifier=foobar&format=Article'

      assert_response :success
      assert_select '.openalex-container', { count: 1 }
    end
  end

  test 'libkey for non-existent identifier does not insert openalex setup when oa_always is true' do
    ClimateControl.modify(FEATURE_OA_ALWAYS: 'true') do
      # Libkey responds here, so we have a cassette - but the response is empty
      VCR.use_cassette('libkey nonexistent') do
        get '/libkey?type=doi&identifier=foobar&format=Article'

        assert_response :success
        assert response.body.blank?
      end
    end
  end

  test 'libkey for non-existent identifier does not insert OpenAlex setup for non-article formats' do
    # OpenAlex should only appear for articles
    VCR.use_cassette('libkey nonexistent') do
      get '/libkey?type=doi&identifier=foobar&format=Book'

      assert_response :success
      assert_select '.openalex-container', { count: 0 }
    end
  end

  test 'libkey no response when either env var is not set' do
    # No cassette because this never results in traffic to Libkey
    ClimateControl.modify(THIRDIRON_ID: nil) do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert response.body.blank?
    end

    ClimateControl.modify(THIRDIRON_KEY: nil) do
      get '/libkey?type=doi&identifier=10.1038/s41567-023-02305-y'

      assert_response :success
      assert response.body.blank?
    end
  end

  test 'browzine route exists with no content' do
    # No cassette because this never results in traffic to Browzine
    get '/browzine'

    assert_response :success
    assert response.body.blank?
  end

  test 'browzine route returns nothing without required parameters' do
    # No cassettes because these never result in traffic to Browzine
    get '/browzine?issn='

    assert response.body.blank?

    get '/browzine?type=doi&identifier=10.1038/s41567-023-02305-y'

    assert response.body.blank?
  end

  test 'browzine route returns HTML for valid parameters' do
    VCR.use_cassette('browzine issn') do
      get '/browzine?issn=1546170X'

      assert_response :success

      # Only browzine link, no button since no full_record_url provided
      assert_select 'a.button', { count: 0 }
      assert_select 'a.libkey-link', { count: 1 }
    end
  end

  test 'browzine route with full_record_url returns both links' do
    VCR.use_cassette('browzine issn') do
      get '/browzine?issn=1546170X&full_record_url=https://example.com/full-record'

      assert_response :success

      # Button (Full-text options) and browzine link both have libkey-link class
      assert_select 'a.button', { count: 1 }
      assert_select 'a.button[href="https://example.com/full-record"]'
      assert_select 'a.libkey-link', { count: 2 }
    end
  end

  test 'browzine route ignores unsafe full_record_url values' do
    VCR.use_cassette('browzine issn') do
      get '/browzine?issn=1546170X&full_record_url=javascript:alert(1)'

      assert_response :success

      # Unsafe URL should not produce a "Full-text options" button
      assert_select 'a.button', { count: 0 }
      assert_select 'a.libkey-link', { count: 1 }
    end
  end

  test 'browzine route for non-existent issn returns blank' do
    # Browzine responds here, so we have a cassette - but the response is empty
    VCR.use_cassette('browzine nonexistent') do
      get '/browzine?issn=0000000X'

      assert_response :success
      assert response.body.blank?
    end
  end

  test 'browzine route when either env var is not set' do
    # No cassette because this never results in traffic to Libkey
    ClimateControl.modify(THIRDIRON_ID: nil) do
      get '/browzine?issn=1546170X'

      assert_response :success
      assert response.body.blank?
    end

    ClimateControl.modify(THIRDIRON_KEY: nil) do
      get '/browzine?issn=1546170X'

      assert_response :success
      assert response.body.blank?
    end
  end
end
