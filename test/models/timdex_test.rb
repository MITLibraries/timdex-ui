require 'test_helper'

class TimdexTest < ActiveSupport::TestCase
  def basic_search
    {
      'q' => 'data',
      'from' => '0'
    }
  end

  def basic_record
    {
      'id' => 'jpal:doi:10.7910-DVN-MNIBOL'
    }
  end

  # RecordQuery
  test 'Timdex record query returns one record' do
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::RecordQuery, variables: basic_record)
      assert response.errors.empty?
      assert_equal 1, response.data.to_h.count
      assert_equal 'Dams, Poverty, Public Goods and Malaria Incidence in India', response.data.to_h['recordId']['title']
    end
  end

  test 'Timdex record query with invalid record' do
    no_record = {
      'id' => 'there.is.no.record'
    }
    VCR.use_cassette('timdex record no record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::RecordQuery, variables: no_record)
      refute response.errors.empty?
      assert response.data.nil?
    end
  end

  test 'Timdex record query with null record' do
    null_record = {
      'id' => nil
    }
    VCR.use_cassette('timdex record null record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::RecordQuery, variables: null_record)
      refute response.errors.empty?
      assert response.data.nil?
    end
  end

  # SearchQuery
  test 'Timdex search query gets expected response types' do
    VCR.use_cassette('data',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: basic_search)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
    end
  end

  test 'Timdex search query throws error with null search' do
    null_search = {
      'q' => nil,
      'from' => '0'
    }
    VCR.use_cassette('timdex null search',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: null_search)
      assert_equal response.class, GraphQL::Client::Response
      assert response.data.nil?
      refute response.errors.empty?
      assert response.errors.messages.count, { minimum: 1 }
    end
  end

  test 'Timdex search query throws error with ridiculous pagination values' do
    big_page_search = {
      'q' => 'data',
      'from' => '31415926537'
    }
    VCR.use_cassette('data from ridiculous start',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: big_page_search)
      assert_equal response.class, GraphQL::Client::Response
      assert response.data.nil?
      refute response.errors.empty?
      assert response.errors.messages.count, { minimum: 1 }
    end
  end

  test 'Timdex search query accepts pagination values' do
    # Load first page of results
    VCR.use_cassette('data',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      first_response = Timdex::Client.query(Timdex::SearchQuery, variables: basic_search)
      first_title = first_response.data.search.to_h['records'].first['title']

      # Load next page of results
      VCR.use_cassette('data page 2',
                       allow_playback_repeats: true,
                       match_requests_on: %i[method uri body]) do
        next_search = {
          'q' => 'data',
          'from' => '20'
        }
        response = Timdex::Client.query(Timdex::SearchQuery, variables: next_search)
        next_title = response.data.search.to_h['records'].first['title']

        refute_equal first_title, next_title
      end
    end
  end

  test 'Timdex search query returns lots of records with empty search' do
    empty_search = {
      'q' => '',
      'from' => '0'
    }
    VCR.use_cassette('timdex empty search',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = Timdex::Client.query(Timdex::SearchQuery, variables: empty_search)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
      assert response.data.search.hits, { minimum: 1 }
    end
  end
end
