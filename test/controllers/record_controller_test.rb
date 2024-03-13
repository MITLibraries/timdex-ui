require 'test_helper'

class RecordControllerTest < ActionDispatch::IntegrationTest
  test 'record with no id returns an error' do
    get '/record'
    assert_response :redirect
    assert_equal 'A record identifier is required.', flash[:error]
  end

  test 'full record path with an id does not return an error' do
    VCR.use_cassette('timdex controller record sample',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get '/record/jpal:doi:10.7910-DVN-MNIBOL'
      assert_response :success
    end
  end

  test 'record ids can include multiple periods' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex controller record no record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get "/record/#{needle_id}"
      assert_response :success
    end
  end

  test 'full record display where no record exists displays an error' do
    needle_id = 'there.is.no.record'
    VCR.use_cassette('timdex controller record no record',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get "/record/#{needle_id}"
      message = 'Record not found'
      assert_select '#content-main', /(.*)#{message}(.*)/
    end
  end

  class RecordControllerGeoTest < RecordControllerTest
    def setup
      @test_strategy = Flipflop::FeatureSet.current.test!
      @test_strategy.switch!(:gdt, true)
    end

    test 'no access button displays if GDT feature is disabled' do
      @test_strategy.switch!(:gdt, false)
      gis_record_id = 'gismit:CAMBRIDGEMEMPOLES09'
      VCR.use_cassette('gis record mit free',
                 allow_playback_repeats: true,
                 match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', count: 0
      end
    end

    test 'access button displays for freely accessible data' do
      gis_record_id = 'gismit:CAMBRIDGEMEMPOLES09'
      VCR.use_cassette('gis record mit free',
                 allow_playback_repeats: true,
                 match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', text: 'Download geodata files',
                                         href: 'https://cdn.dev1.mitlibrary.net/geo/public/CAMBRIDGEMEMPOLES09.zip'
      end
    end

    test 'access button displays for data requiring MIT auth' do
      gis_record_id = 'gismit:us_ma_boston_g47parcels_2018'
      VCR.use_cassette('gis record mit auth',
                 allow_playback_repeats: true,
                 match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', text: 'Download geodata files MIT authentication',
                           href: 'https://cdn.dev1.mitlibrary.net/geo/restricted/us_ma_boston_g47parcels_2018.zip'
      end
    end

    test 'access button displays for non-MIT GIS records' do
      gis_record_id = 'gisogm:edu.stanford.purl:be6ef8cd8ac5'
      VCR.use_cassette('gis record elsewhere',
                 allow_playback_repeats: true,
                 match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', text: 'View Stanford record', href: 'https://purl.stanford.edu/kv971cf1984'
      end
    end
  end
end
