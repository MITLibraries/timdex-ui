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

  test 'availability helper handles known statuses correctly' do
    location = ['Main Library', 'First Floor', 'QA76.73.R83 2023']

    available_blurb = availability('available', location, false)
    assert_includes available_blurb, 'Available in'
    assert_includes available_blurb, location(location)

    check_holdings_blurb = availability('check_holdings', location, false)
    assert_includes check_holdings_blurb, 'May be available in'
    assert_includes check_holdings_blurb, location(location)

    unavailable_blurb = availability('unavailable', location, false)
    assert_includes unavailable_blurb, 'Not currently available in'
    assert_includes unavailable_blurb, location(location)

    unknown_blurb = availability('unknown_status', location, false)
    assert_includes unknown_blurb, 'Uncertain availability in'
    assert_includes unknown_blurb, location(location)
  end
end
