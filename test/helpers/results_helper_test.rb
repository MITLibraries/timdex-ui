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
    ResultsHelper::TAB_DESCRIPTIONS.each do |tab, expected|
      params[:tab] = tab
      assert_equal expected, tab_description, "Expected description for tab '#{tab}' to match TAB_DESCRIPTIONS"
    end
  end

  test 'tab_description returns empty string for unknown tabs' do
    params[:tab] = 'unknown_tab'
    assert_equal '', tab_description
  end

  test 'tab_description returns empty string for nil tab' do
    params[:tab] = nil
    assert_equal '', tab_description
  end

  test 'tab_description returns empty string for empty tab' do
    params[:tab] = ''
    assert_equal '', tab_description
  end

  test 'search_primo_link includes encoded search query and correct path' do
    params[:q] = 'breakfast of champions'
    link = search_primo_link

    assert link.start_with?('https://')
    assert_includes link, '/discovery/search?'
    assert_includes link, 'query=any%2Ccontains%2Cbreakfast+of+champions'
    assert_includes link, 'tab=all'
    assert_includes link, 'search_scope=cdi'
    assert_includes link, 'vid=01MIT_INST%3AMIT'
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

  test 'article? returns true for Article format' do
    assert article?('Article')
    assert article?('Journal Article')
    assert article?('Newspaper Article')
  end

  test 'article? returns true for lowercase article formats' do
    assert article?('article')
    assert article?('journal article')
    assert article?('newspaper article')
  end

  test 'article? returns true for mixed case article formats' do
    assert article?('ARTICLE')
    assert article?('Article')
    assert article?('JoUrNaL ArTiClE')
  end

  test 'article? returns false for non-article formats' do
    assert_not article?('Journal')
    assert_not article?('eBook')
    assert_not article?('Book Chapter')
    assert_not article?('Conference Proceeding')
    assert_not article?('Reference Entry')
    assert_not article?('Research Database')
    assert_not article?('Dataset')
  end

  test 'article? returns false for blank or nil format' do
    assert_not article?(nil)
    assert_not article?('')
  end
end
