require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  test 'url returns a querystring' do
    expected = 'q=blah'
    search = { q: 'blah' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder trims spaces' do
    expected = 'q=blah'
    search = { q: ' blah ' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder escapes single quotes' do
    expected = 'q=don%27t'
    search = { q: "don't" }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts double quotes to single quotes' do
    expected = 'q=say+%27ahh%27+please'
    search = { q: 'say "ahh" please' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder deals with phrases' do
    expected = 'q=buttered+popcorn'
    search = { q: 'buttered popcorn' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end
end
