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

  test 'result_get? returns true when result has links' do
    assert result_get?({ links: [{ 'kind' => 'PDF', 'url' => 'https://example.com' }] })
  end

  test 'result_get? returns true when result has a valid Alma ID' do
    assert result_get?({ identifier: 'alma9912346761' })
  end

  test 'result_get? returns true when ThirdIron enabled and result has doi' do
    ClimateControl.modify(THIRDIRON_ID: '123', THIRDIRON_KEY: 'abc') do
      assert result_get?({ doi: '10.1234/test' })
    end
  end

  test 'result_get? returns true when ThirdIron enabled and result has pmid' do
    ClimateControl.modify(THIRDIRON_ID: '123', THIRDIRON_KEY: 'abc') do
      assert result_get?({ pmid: '12345678' })
    end
  end

  test 'result_get? returns true when ThirdIron enabled and result is a journal with issn' do
    ClimateControl.modify(THIRDIRON_ID: '123', THIRDIRON_KEY: 'abc') do
      assert result_get?({ format: 'Journal', issn: '1234-5678' })
    end
  end

  test 'result_get? returns true when oa_always enabled and result is an article' do
    ClimateControl.modify(FEATURE_OA_ALWAYS: 'true') do
      assert result_get?({ format: 'Article' })
    end
  end

  test 'result_get? returns false when result has no fulfillment content' do
    ClimateControl.modify(THIRDIRON_ID: nil, THIRDIRON_KEY: nil, FEATURE_OA_ALWAYS: nil) do
      assert_not result_get?({})
      assert_not result_get?({ format: 'Book' })
    end
  end

  test 'result_get? returns false when ThirdIron disabled even with doi' do
    ClimateControl.modify(THIRDIRON_ID: nil, THIRDIRON_KEY: nil) do
      assert_not result_get?({ doi: '10.1234/test' })
    end
  end

  test 'result_get? returns false when oa_always disabled and result has no links' do
    ClimateControl.modify(FEATURE_OA_ALWAYS: nil, THIRDIRON_ID: nil, THIRDIRON_KEY: nil) do
      assert_not result_get?({ format: 'Article' })
    end
  end

  test 'result_get? returns false when result has only full record link and feature is disabled' do
    ClimateControl.modify(FEATURE_RECORD_LINK: nil, THIRDIRON_ID: nil, THIRDIRON_KEY: nil, FEATURE_OA_ALWAYS: nil) do
      assert_not result_get?({ links: [{ 'kind' => 'Full Record', 'url' => 'https://example.com' }] })
    end
  end

  test 'result_get? returns true when result has only full record link and feature is enabled' do
    ClimateControl.modify(FEATURE_RECORD_LINK: 'true', THIRDIRON_ID: nil, THIRDIRON_KEY: nil, FEATURE_OA_ALWAYS: nil) do
      assert result_get?({ links: [{ 'kind' => 'Full Record', 'url' => 'https://example.com' }] })
    end
  end

  test 'result_get? returns true when result has PDF link even if record_link feature is disabled' do
    ClimateControl.modify(FEATURE_RECORD_LINK: nil, THIRDIRON_ID: nil, THIRDIRON_KEY: nil, FEATURE_OA_ALWAYS: nil) do
      assert result_get?({ links: [{ 'kind' => 'PDF', 'url' => 'https://example.com' }] })
    end
  end

  test 'result_get? returns true when result has both full record and PDF links even if record_link feature is disabled' do
    ClimateControl.modify(FEATURE_RECORD_LINK: nil, THIRDIRON_ID: nil, THIRDIRON_KEY: nil, FEATURE_OA_ALWAYS: nil) do
      assert result_get?({
                           links: [
                             { 'kind' => 'Full Record', 'url' => 'https://example.com' },
                             { 'kind' => 'PDF', 'url' => 'https://pdf.example.com' }
                           ]
                         })
    end
  end

  test 'full_record_url returns the URL when result has a full record link' do
    result = {
      links: [
        { 'kind' => 'PDF', 'url' => 'https://pdf.example.com' },
        { 'kind' => 'full record', 'url' => 'https://primo.example.com/record' }
      ]
    }
    assert_equal 'https://primo.example.com/record', full_record_url(result)
  end

  test 'full_record_url returns nil when result has no links' do
    result = {}
    assert_nil full_record_url(result)
  end

  test 'full_record_url returns nil when result has links but no full record link' do
    result = {
      links: [
        { 'kind' => 'PDF', 'url' => 'https://pdf.example.com' },
        { 'kind' => 'HTML', 'url' => 'https://html.example.com' }
      ]
    }
    assert_nil full_record_url(result)
  end

  test 'full_record_url returns nil when result is nil' do
    assert_nil full_record_url(nil)
  end

  test 'full_record_url returns nil when result[:links] is nil' do
    result = { links: nil }
    assert_nil full_record_url(result)
  end
end
