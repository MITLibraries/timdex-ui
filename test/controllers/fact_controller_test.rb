require 'test_helper'

class FactControllerTest < ActionDispatch::IntegrationTest
  test 'doi with no doi' do
    get '/doi'
    assert_response :success

    refute @response.body.present?
  end

  test 'doi with valid doi and no oa copy available' do
    VCR.use_cassette('fact doi 10.1038.nphys1170',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/doi?doi=10.1038%2Fnphys1170'
      assert_response :success

      assert @response.body.present?

      assert_select '#doi-fact', { count: 1 }
      assert_select '#isbn-fact', { count: 0 }
      assert_select '#issn-fact', { count: 0 }
      assert_select '#pmid-fact', { count: 0 }

      assert_select 'a', text: 'Check MIT Subscription Access', count: 1
      assert_select 'a', text: 'Open Access Link', count: 0
    end
  end

  test 'doi with valid doi and oa copy available' do
    VCR.use_cassette('fact doi 10.1126 sciadv.abj1076',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/doi?doi=10.1126%2Fsciadv.abj1076'
      assert_response :success

      assert @response.body.present?

      assert_select '#doi-fact', { count: 1 }
      assert_select '#isbn-fact', { count: 0 }
      assert_select '#issn-fact', { count: 0 }
      assert_select '#pmid-fact', { count: 0 }

      assert_select 'a', text: 'Check MIT Subscription Access', count: 1
      assert_select 'a', text: 'Open Access Link', count: 1
    end
  end

  test 'doi with no data returned' do
    VCR.use_cassette('fact doi 10.3207.2959859860',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/doi?doi=10.3207/2959859860'
      assert_response :success

      refute @response.body.present?
    end
  end

  test 'isbn with no isbn' do
    get '/isbn'
    assert_response :success

    refute @response.body.present?
  end

  test 'isbn with valid isbn' do
    VCR.use_cassette('fact ISBN 9780399563423',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/isbn?isbn=9780399563423'
      assert_response :success

      assert @response.body.present?

      assert_select '#doi-fact', { count: 0 }
      assert_select '#isbn-fact', { count: 1 }
      assert_select '#issn-fact', { count: 0 }
      assert_select '#pmid-fact', { count: 0 }

      assert_select 'a', text: 'The Morning Star', href: 'https://mit.primo.exlibrisgroup.com/discovery/openurl?institution=01MIT_INST&vid=01MIT_INST:MIT&rft.isbn=9780399563423'
      assert_select 'li', text: 'Karl Ove Knausgaard ; Martin Aitken'
    end
  end

  test 'isbn with no data returned' do
    VCR.use_cassette('fact ISBN asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/isbn?isbn=asdf'
      assert_response :success

      refute @response.body.present?
    end
  end

  test 'issn with no issn' do
    get '/issn'
    assert_response :success

    refute @response.body.present?
  end

  test 'issn with no data returned' do
    VCR.use_cassette('fact ISSN asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/issn?issn=asdf'
      assert_response :success

      refute @response.body.present?
    end
  end

  test 'issn with invalid issn' do
    # This is invalid because the check digit, 8, is not correct
    VCR.use_cassette('fact ISSN 1234-5678',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/issn?issn=1234-5678'
      assert_response :success

      refute @response.body.present?
    end
  end

  test 'issn with valid but unused issn' do
    # This ISSN is internally valid, but currently unassigned
    VCR.use_cassette('fact ISSN 2015-223x',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/issn?issn=2015-223x'
      assert_response :success

      refute @response.body.present?
    end
  end

  test 'issn with real issn' do
    VCR.use_cassette('fact ISSN 1087-5549',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/issn?issn=1087-5549'
      assert_response :success

      assert @response.body.present?

      assert_select '#doi-fact', { count: 0 }
      assert_select '#isbn-fact', { count: 0 }
      assert_select '#issn-fact', { count: 1 }
      assert_select '#pmid-fact', { count: 0 }
    end
  end

  test 'pmid with no pmid' do
    get '/pmid'
    assert_response :success

    refute @response.body.present?
  end

  test 'pmid with valid pmid' do
    VCR.use_cassette('fact PMID 20104584',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/pmid?pmid=PMID%3A+20104584'
      assert_response :success

      assert @response.body.present?

      assert_select '#doi-fact', { count: 0 }
      assert_select '#isbn-fact', { count: 0 }
      assert_select '#issn-fact', { count: 0 }
      assert_select '#pmid-fact', { count: 1 }
    end
  end

  test 'pmid with invalid pmid' do
    VCR.use_cassette('fact PMID asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/pmid?pmid=PMID%3A+asdf'
      assert_response :success

      refute @response.body.present?
    end
  end
end
