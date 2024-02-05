require 'test_helper'

class ResultsHelperTest < ActionView::TestCase
  include ResultsHelper

  test 'if number of hits is equal to 10,000, results summary returns "10,000+"' do
    hits = 10000
    assert_equal '10,000+ items', results_summary(hits)
  end

  test 'if number of hits is above 10,000, results summary returns "10,000+"' do
    hits = 10500
    assert_equal '10,000+ items', results_summary(hits)
  end

  test 'if number of hits is below 10,000, results summary returns actual number of results' do
    hits = 9000
    assert_equal '9,000 items', results_summary(hits)
  end
end
