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
      'id' => 'jpal:doi:10.7910-DVN-MNIBOL', 'index' => ENV.fetch('TIMDEX_INDEX', nil).to_s
    }
  end

  # RecordQuery
  test 'Timdex record query returns one record' do
    VCR.use_cassette('timdex record sample',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = TimdexBase::Client.query(TimdexRecord::Query, variables: basic_record)
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
      response = TimdexBase::Client.query(TimdexRecord::Query, variables: no_record)
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
      response = TimdexBase::Client.query(TimdexRecord::Query, variables: null_record)
      refute response.errors.empty?
      assert response.data.nil?
    end
  end

  # SearchQuery
  test 'Timdex search query gets expected response types' do
    VCR.use_cassette('data',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: basic_search)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
    end
  end

  test 'Timdex search returns all records with null search' do
    # note, this behavior is prevented in basic search controller by ensuring q is a valid search
    # however, to allow for complex advanced searches including potentially just browsing all records from a single
    # source, we are not preventing this functionality at the timdex query level and controllers should do the
    # appropriate checking to prevent undesired results.
    null_search = {
      'q' => nil,
      'from' => '0'
    }
    VCR.use_cassette('timdex null search',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: null_search)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.nil?
      assert response.errors.empty?
      assert_equal response.errors.messages.count, 0
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
      response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: big_page_search)
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
      first_response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: basic_search)
      first_title = first_response.data.search.to_h['records'].first['title']

      # Load next page of results
      VCR.use_cassette('data page 2',
                       allow_playback_repeats: true,
                       match_requests_on: %i[method uri body]) do
        next_search = {
          'q' => 'data',
          'from' => '20'
        }
        response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: next_search)
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
      response = TimdexBase::Client.query(TimdexSearch::BaseQuery, variables: empty_search)
      assert_equal response.class, GraphQL::Client::Response
      refute response.data.search.nil?
      assert response.errors.empty?
      assert response.data.search.hits, { minimum: 1 }
    end
  end
end
