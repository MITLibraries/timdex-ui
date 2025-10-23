require 'test_helper'

class RecordControllerGeoTest < ActionDispatch::IntegrationTest
  test 'no access button displays if GDT feature is disabled' do
    gis_record_id = 'gismit:CAMBRIDGEMEMPOLES09'
    VCR.use_cassette('gis record mit free',
                     allow_playback_repeats: true,
                     match_requests_on: %i[method uri body]) do
      get "/record/#{gis_record_id}"
      assert_select 'a.access-button', count: 0
    end
  end

  test 'access button displays for freely accessible data' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      gis_record_id = 'gismit:CAMBRIDGEMEMPOLES09'
      VCR.use_cassette('gis record mit free',
                       allow_playback_repeats: true,
                       match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', text: 'Download geodata files',
                                         href: 'https://cdn.dev1.mitlibrary.net/geo/public/CAMBRIDGEMEMPOLES09.zip'
      end
    end
  end

  test 'access button displays for data requiring MIT auth' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      gis_record_id = 'gismit:us_ma_boston_g47parcels_2018'
      VCR.use_cassette('gis record mit auth',
                       allow_playback_repeats: true,
                       match_requests_on: %i[method uri body]) do
        get "/record/#{gis_record_id}"
        assert_select 'a.access-button', text: 'Download geodata files MIT authentication',
                                         href: 'https://cdn.dev1.mitlibrary.net/geo/restricted/us_ma_boston_g47parcels_2018.zip'
      end
    end
  end

  test 'access button displays for non-MIT GIS records' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
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
