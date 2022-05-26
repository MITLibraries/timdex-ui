require 'test_helper'

class AnalyzerTest < ActiveSupport::TestCase
  test 'analyzer pagination includes three values at start of results' do
    VCR.use_cassette('data',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      eq = {
        q: 'data',
        page: 1
      }
      query = { 'q' => 'data', 'from' => '0' }
      response = TimdexBase::Client.query(TimdexSearch::Query, variables: query)
      pagination = Analyzer.new(eq, response).pagination

      assert pagination.key?(:hits)
      assert pagination.key?(:next)
      assert pagination.key?(:page)

      refute pagination.key?(:prev)
    end
  end

  test 'analyzer pagination includes four values in middle page of results' do
    VCR.use_cassette('data page 2',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      eq = {
        q: 'data',
        page: 2
      }
      query = { 'q' => 'data', 'from' => '20' }
      response = TimdexBase::Client.query(TimdexSearch::Query, variables: query)
      pagination = Analyzer.new(eq, response).pagination

      assert pagination.key?(:hits)
      assert pagination.key?(:next)
      assert pagination.key?(:prev)
      assert pagination.key?(:page)
    end
  end

  test 'analyzer pagination includes three values at end of results' do
    VCR.use_cassette('data last page',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      eq = {
        q: 'data',
        page: 17
      }
      query = { 'q' => 'data', 'from' => '320' }
      response = TimdexBase::Client.query(TimdexSearch::Query, variables: query)
      pagination = Analyzer.new(eq, response).pagination

      assert pagination.key?(:hits)
      assert pagination.key?(:prev)
      assert pagination.key?(:page)

      assert_nil pagination[:next]
    end
  end
end
