require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  test 'url returns a querystring' do
    expected = 'full=false&page=1&q=blah'
    search = 'blah'
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder trims spaces' do
    expected = 'full=false&page=1&q=blah'
    search = ' blah '
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder escapes single quotes' do
    expected = 'full=false&page=1&q=don%27t'
    search = "don't"
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts double quotes to single quotes' do
    expected = 'full=false&page=1&q=say+%27ahh%27+please'
    search = 'say "ahh" please'
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder deals with phrases' do
    expected = 'full=false&page=1&q=buttered+popcorn'
    search = 'buttered popcorn'
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end
end
