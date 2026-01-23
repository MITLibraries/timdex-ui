require 'test_helper'

class ResultsHelperTest < ActionView::TestCase
  include ResultsHelper

  require 'uri'

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
    description = 'Journal and newspaper articles, book reviews, book chapters, and more'
    assert_equal description, tab_description

    params[:tab] = 'alma'
    description = 'Books, e-books, journals, streaming and physical media, and more'
    assert_equal description, tab_description

    params[:tab] = 'timdex_alma'
    description = 'Books, e-books, journals, streaming and physical media, and more'
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

  test 'search_primo_params includes encoded search query' do
    params[:q] = 'breakfast of champions'
    result = search_primo_params

    assert_includes result, 'query=any%2Ccontains%2Cbreakfast+of+champions'
    assert_includes result, 'tab=all'
    assert_includes result, 'search_scope=all'
  end

  test 'search_primo_link returns a valid URL string' do
    params[:q] = 'test query'
    link = search_primo_link

    assert link.start_with?('https://')
    assert_includes link, '/discovery/search?'
    assert_includes link, 'query=any%2Ccontains%2Ctest+query'
  end

  test 'search_aspace_link returns a valid archivesspace search URL' do
    params[:q] = 'minutes'
    link = search_aspace_link

    assert link.start_with?('https://archivesspace.mit.edu/search?')
    assert_includes link, 'q%5B%5D=minutes'
  end

  test 'search_worldcat_link returns a valid worldcat search URL' do
    params[:q] = 'climate change'
    link = search_worldcat_link

    assert link.start_with?('https://mit.on.worldcat.org/search?')
    assert_includes link, 'queryString=climate+change'
  end
end
