require 'test_helper'

class TimdexTest < ActiveSupport::TestCase
  def basic_query
    {
      'q' => 'data'
    }
  end

  test 'timdex wrapper gets expected response types' do
    VCR.use_cassette('data',
                     allow_playback_repeats: true) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: basic_query)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
    end
  end

  test 'timdex wrapper throws error with null search' do
    null_query = {
      'q' => nil
    }
    VCR.use_cassette('timdex null search',
                     allow_playback_repeats: true) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: null_query)
      assert_equal response.class, GraphQL::Client::Response
      assert response.data.nil?
      refute response.errors.empty?
      assert response.errors.messages.count, { minimum: 1 }
    end
  end

  test 'timdex wrapper returns lots of records with empty search' do
    null_query = {
      'q' => ''
    }
    VCR.use_cassette('timdex empty search',
                     allow_playback_repeats: true) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: null_query)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
      assert response.data.search.hits, { minimum: 1 }
    end
  end
end
