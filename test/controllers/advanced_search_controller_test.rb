require 'test_helper'

class AdvancedSearchControllerTest < ActionDispatch::IntegrationTest
  test 'advanced search route exists and renders' do
    get '/advanced-search'
    assert_response :success
  end

  test 'initial form state' do
    get '/advanced-search'

    assert_select 'form#advanced-search', { count: 1 }
    assert_select 'form#advanced-search input#advanced-keyword', { count: 1 }
    assert_select 'form#advanced-search input#advanced-citation', { count: 1 }
    assert_select 'form#advanced-search input#advanced-contributors', { count: 1 }
    assert_select 'form#advanced-search input#advanced-fundingInformation', { count: 1 }
    assert_select 'form#advanced-search input#advanced-identifiers', { count: 1 }
    assert_select 'form#advanced-search input#advanced-locations', { count: 1 }
    assert_select 'form#advanced-search input#advanced-subjects', { count: 1 }
    assert_select 'form#advanced-search input#advanced-title', { count: 1 }
    assert_select 'form#advanced-search select#advanced-source', { count: 1 }
  end

  # add test for filling out and submitting each field individually
  test 'advanced search by keyword' do
    VCR.use_cassette('advanced keyword asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?q=asdf&advanced=true'
      assert_response :success
      assert_nil flash[:error]

      assert_select 'li', 'Keyword anywhere: asdf'
    end
  end

  test 'can search an advanced field without a keyword search' do
    # note, this confirms we only validate param[:q] is present for basic searches
    VCR.use_cassette('advanced citation asdf',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/results?citation=asdf&advanced=true'
      assert_response :success
      assert_nil flash[:error]

      assert_select 'li', 'Citation: asdf'
    end
  end

  test 'advanced search can accept values from all fields' do
    VCR.use_cassette('advanced all',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      query = {
        q: 'data',
        citation: 'citation',
        contributors: 'contribs',
        fundingInformation: 'fund',
        identifiers: 'ids',
        locations: 'locs',
        subjects: 'subs',
        title: 'title',
        source: 'sauce',
        advanced: 'true'
      }.to_query
      get "/results?#{query}"
      assert_response :success
      assert_nil flash[:error]

      assert_select 'li', 'Keyword anywhere: data'
      assert_select 'li', 'Citation: citation'
      assert_select 'li', 'Contributors: contribs'
      assert_select 'li', 'Funders: fund'
      assert_select 'li', 'Identifiers: ids'
      assert_select 'li', 'Locations: locs'
      assert_select 'li', 'Subjects: subs'
      assert_select 'li', 'Title: title'
      assert_select 'li', 'Source: sauce'
    end
  end
end
