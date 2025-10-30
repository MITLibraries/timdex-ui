require 'test_helper'

class PaginationHelperTest < ActionView::TestCase
  include PaginationHelper

  test 'Next links for basic search' do
    @pagination = { next: 12 }
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="Next page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=12&amp;q=popcorn">Next &raquo;</a>', next_url(query_params)
    )
  end

  test 'Next links for advanced search' do
    @pagination = { next: 12 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn' }
    assert_equal(
      '<a aria-label="Next page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?contributors=yawn&amp;page=12&amp;q=popcorn&amp;title=titles+are+cool">Next &raquo;</a>',
      next_url(query_params)
    )
  end

  test 'Previous links for basic search' do
    @pagination = { prev: 11 }
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="Previous page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=11&amp;q=popcorn">&laquo; Previous</a>', prev_url(query_params)
    )
  end

  test 'Previous links for advanced search' do
    @pagination = { prev: 11 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn' }
    assert_equal(
      '<a aria-label="Previous page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?contributors=yawn&amp;page=11&amp;q=popcorn&amp;title=titles+are+cool">&laquo; Previous</a>',
      prev_url(query_params)
    )
  end

  test 'Next links preserve active tab' do
    @pagination = { next: 12 }
    @active_tab = 'primo'
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="Next page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=12&amp;q=popcorn&amp;tab=primo">Next &raquo;</a>', next_url(query_params)
    )
  end

  test 'Previous links preserve active tab' do
    @pagination = { prev: 11 }
    @active_tab = 'timdex'
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="Previous page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=11&amp;q=popcorn&amp;tab=timdex">&laquo; Previous</a>', prev_url(query_params)
    )
  end

  test 'First links for basic search' do
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="First page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=1&amp;q=popcorn">&laquo;&laquo; First</a>', first_url(query_params)
    )
  end

  test 'First links preserve active tab' do
    @active_tab = 'primo'
    query_params = { q: 'popcorn' }
    assert_equal(
      '<a aria-label="First page" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=1&amp;q=popcorn&amp;tab=primo">&laquo;&laquo; First</a>', first_url(query_params)
    )
  end
end
