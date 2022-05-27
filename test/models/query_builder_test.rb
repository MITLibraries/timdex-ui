require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  test 'url returns a querystring' do
    expected = 'from=0&q=blah'
    search = { q: 'blah' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder trims spaces' do
    expected = 'from=0&q=blah'
    search = { q: ' blah ' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder escapes single quotes' do
    expected = 'from=0&q=don%27t'
    search = { q: "don't" }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts double quotes to single quotes' do
    expected = 'from=0&q=say+%27ahh%27+please'
    search = { q: 'say "ahh" please' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder deals with phrases' do
    expected = 'from=0&q=buttered+popcorn'
    search = { q: 'buttered popcorn' }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  # From parameter
  test 'query builder sets from to 0 if somehow it is not set earlier' do
    # This test shouldn't be needed, as the Enhancer should always return a positive integer. But I am paranoid.
    expected = 'from=0&q=test'
    search = {
      q: 'test'
    }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts gibberish page number to item count 0' do
    # This test shouldn't be needed, as the Enhancer should always return a positive integer. But I am paranoid.
    expected = 'from=0&q=test'
    search = {
      q: 'test',
      page: 'foo'
    }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts page number 1 to item count 0' do
    expected = 'from=0&q=test'
    search = {
      q: 'test',
      page: 1
    }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end

  test 'query builder converts page number 2 to item count 20' do
    expected = 'from=20&q=test'
    search = {
      q: 'test',
      page: 2
    }
    assert_equal(expected, QueryBuilder.new(search).querystring)
  end
end
