require 'test_helper'

class PaginationHelperTest < ActionView::TestCase
  include PaginationHelper

  test 'Next links for basic search' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    query_params = { q: 'popcorn', page: 12 }
    assert_equal(
      '<a aria-label="Next 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=13&amp;q=popcorn">Next 20 results</a>', next_url(query_params)
    )
  end

  test 'Next links for advanced search' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn' }
    assert_equal(
      '<a aria-label="Next 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?contributors=yawn&amp;page=13&amp;q=popcorn&amp;title=titles+are+cool">Next 20 results</a>',
      next_url(query_params)
    )
  end

  test 'Previous links for basic search' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    query_params = { q: 'popcorn', page: 12 }
    assert_equal(
      '<a aria-label="Previous 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=11&amp;q=popcorn">Previous 20 results</a>', prev_url(query_params)
    )
  end

  test 'Previous links for advanced search' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn', page: 12 }
    assert_equal(
      '<a aria-label="Previous 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?contributors=yawn&amp;page=11&amp;q=popcorn&amp;title=titles+are+cool">Previous 20 results</a>',
      prev_url(query_params)
    )
  end

  test 'Next links preserve active tab' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    @active_tab = 'primo'
    query_params = { q: 'popcorn', page: 12 }
    assert_equal(
      '<a aria-label="Next 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=13&amp;q=popcorn&amp;tab=primo">Next 20 results</a>', next_url(query_params)
    )
  end

  test 'Previous links preserve active tab' do
    @pagination = { prev: 11, next: 13, per_page: 20, hits: 1000, end: 260 }
    @active_tab = 'timdex'
    query_params = { q: 'popcorn', page: 12 }
    assert_equal(
      '<a aria-label="Previous 20 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=11&amp;q=popcorn&amp;tab=timdex">Previous 20 results</a>', prev_url(query_params)
    )
  end

  test 'First links for initial basic search is disabled' do
    query_params = { q: 'popcorn' }
    assert_equal(
      '<span role="link" aria-disabled="true" tabindex="-1">First</span>', first_url(query_params)
    )
  end

  test 'First links preserve active tab' do
    @active_tab = 'primo'
    query_params = { q: 'popcorn', page: 5 }
    assert_equal(
      '<a aria-label="First" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=1&amp;q=popcorn&amp;tab=primo">First</a>', first_url(query_params)
    )
  end

  test 'Next link for penultimate page is correct' do
    @pagination = { next: 6, per_page: 20, hits: 102, end: 100 }
    query_params = { q: 'popcorn', page: 5 }
    assert_equal(
      '<a aria-label="Next 2 results" data-turbo-frame="search-results" data-turbo-action="advance" rel="nofollow" href="/results?page=6&amp;q=popcorn">Next 2 results</a>', next_url(query_params)
    )
  end

  test 'Next link for full last page is disabled' do
    @pagination = { next: 6, per_page: 20, hits: 100, end: 100 }
    query_params = { q: 'popcorn', page: 5 }
    assert_equal(
      "<span role='link' aria-disabled='true' tabindex='-1'>Next 0 results</span>", next_url(query_params)
    )
  end

  test 'Previous link for first page is disabled' do
    @pagination = { prev: nil, per_page: 20, hits: 100, end: 20 }
    query_params = { q: 'popcorn', page: 1 }
    assert_equal(
      "<span role='link' aria-disabled='true' tabindex='-1'>Previous 20 results</span>", prev_url(query_params)
    )
  end
end
