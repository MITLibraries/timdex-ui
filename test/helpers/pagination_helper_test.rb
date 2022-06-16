require 'test_helper'

class PaginationHelperTest < ActionView::TestCase
  include PaginationHelper

  test 'Next links for basic search' do
    @pagination = { next: 12 }
    query_params = { q: 'popcorn' }
    assert_equal('<a class="btn button-primary" href="/results?page=12&amp;q=popcorn">Next page <span class="fa fa-chevron-right"></span></a>', next_url(query_params))
  end

  test 'Next links for advanced search' do
    @pagination = { next: 12 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn' }
    assert_equal(
      '<a class="btn button-primary" href="/results?contributors=yawn&amp;page=12&amp;q=popcorn&amp;title=titles+are+cool">Next page <span class="fa fa-chevron-right"></span></a>',
      next_url(query_params)
    )
  end

  test 'Previous links for basic search' do
    @pagination = { prev: 11 }
    query_params = { q: 'popcorn' }
    assert_equal('<a class="btn button-primary" href="/results?page=11&amp;q=popcorn"><span class="fa fa-chevron-left"></span> Previous page</a>', prev_url(query_params))
  end

  test 'Previous links for advanced search' do
    @pagination = { prev: 11 }
    query_params = { q: 'popcorn', title: 'titles are cool', contributors: 'yawn' }
    assert_equal(
      '<a class="btn button-primary" href="/results?contributors=yawn&amp;page=11&amp;q=popcorn&amp;title=titles+are+cool"><span class="fa fa-chevron-left"></span> Previous page</a>',
      prev_url(query_params)
    )
  end
end
