require 'test_helper'

class ResultsHelperTest < ActionView::TestCase
  include ResultsHelper

  test 'if number of hits is equal to 10,000, results summary returns "10,000+"' do
    hits = 10_000
    assert_equal '10,000+ results', results_summary(hits)
  end

  test 'if number of hits is above 10,000, results summary returns "10,000+"' do
    hits = 10_500
    assert_equal '10,000+ results', results_summary(hits)
  end

  test 'if number of hits is below 10,000, results summary returns actual number of results' do
    hits = 9000
    assert_equal '9,000 results', results_summary(hits)
  end

  test 'result helper handles tab descriptions for tabs based on params hash' do
    params[:tab] = 'all'
    description = 'All MIT Libraries sources'
    assert_equal description, tab_description

    params[:tab] = 'cdi'
    description = 'Journal and newspaper articles, book chapters, and more'
    assert_equal description, tab_description

    params[:tab] = 'alma'
    description = 'Books, journals, streaming and physical media, and more'
    assert_equal description, tab_description

    params[:tab] = 'timdex_alma'
    description = 'Books, journals, streaming and physical media, and more'
    assert_equal description, tab_description

    params[:tab] = 'primo'
    description = 'Articles, books, chapters, streaming and physical media, and more'
    assert_equal description, tab_description

    params[:tab] = 'aspace'
    description = 'Archives, manuscripts, and other unique materials related to MIT'
    assert_equal description, tab_description

    params[:tab] = 'timdex'
    description = 'Digital collections, images, documents, and more from MIT Libraries'
    assert_equal description, tab_description

    params[:tab] = 'website'
    description = 'Information about the library: events, news, services, and more'
    assert_equal description, tab_description
  end
end
