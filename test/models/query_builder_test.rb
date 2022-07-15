require 'test_helper'

class QueryBuilderTest < ActiveSupport::TestCase
  test 'query builder trims spaces' do
    expected = { 'from' => '0', 'q' => 'blah' }
    search = { q: ' blah ' }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder handles supported fields' do
    expected = { 'from' => '0', 'q' => 'blah', 'citation' => 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
                 'contributors' => 'Vonnegut, Kurt', 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'locations' => 'Cambridge, MA',
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles' }
    search = {
      q: ' blah ',
      citation: 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123',
      locations: 'Cambridge, MA',
      subjects: 'Subjects are the worst',
      title: 'Hi I like titles'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder ignores unsupported fields' do
    expected = { 'from' => '0', 'q' => 'blah', 'citation' => 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
                 'contributors' => 'Vonnegut, Kurt', 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123', 'locations' => 'Cambridge, MA',
                 'subjects' => 'Subjects are the worst', 'title' => 'Hi I like titles' }
    search = {
      q: ' blah ',
      citation: 'Citations are cool. Journal of cool citations. Vol 3, page 123.',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123',
      locations: 'Cambridge, MA',
      subjects: 'Subjects are the worst',
      title: 'Hi I like titles',
      fake: 'I will not show up in the output'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder ignores supported fields that were not included' do
    expected = { 'from' => '0', 'q' => 'blah', 'contributors' => 'Vonnegut, Kurt',
                 'fundingInformation' => 'National Science Foundation',
                 'identifiers' => 'doi://1234.123/123.123' }
    search = {
      q: ' blah ',
      contributors: 'Vonnegut, Kurt',
      fundingInformation: 'National Science Foundation',
      identifiers: 'doi://1234.123/123.123'
    }
    assert_equal(expected, QueryBuilder.new(search).query)
  end

  test 'query builder can read TIMDEX_INDEX from env' do
    ClimateControl.modify TIMDEX_INDEX: 'rdi*' do
      search = { q: 'blah' }
      assert_equal('rdi*', QueryBuilder.new(search).query['index'])
    end
  end

  test 'query builder index is nil if TIMDEX_INDEX not provided in env' do
    search = { q: 'blah' }
    assert_nil(QueryBuilder.new(search).query['index'])
  end
end
