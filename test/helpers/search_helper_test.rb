require 'test_helper'

class SearchHelperTest < ActionView::TestCase
  include SearchHelper

  test 'removes displayed fields from highlights' do
    result = { highlight: [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                           { 'matchedField' => 'title.exact_value', 'matchedPhrases' => 'Very important data' },
                           { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                           { 'matchedField' => 'dates.value', 'matchedPhrases' => '2022' },
                           { 'matchedField' => 'contributors.value', 'matchedPhrases' => 'Jane Datascientist' }] }
    assert_empty trim_highlights(result)
  end

  test 'does not remove undisplayed fields from highlights' do
    result = { highlight: [{ 'matchedField' => 'notes', 'matchedPhrases' => 'Have some data' }] }
    assert_equal [{ 'matchedField' => 'notes', 'matchedPhrases' => 'Have some data' }], trim_highlights(result)
  end

  test 'returns correct set of highlights when result includes displayed and undisplayed fields' do
    result = { highlight: [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                           { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                           { 'matchedField' => 'numbering', 'matchedPhrases' => '2022' },
                           { 'matchedField' => 'notes', 'matchedPhrases' => 'Datascientist, Jane' }] }
    assert_equal [{ 'matchedField' => 'numbering', 'matchedPhrases' => '2022' },
                  { 'matchedField' => 'notes', 'matchedPhrases' => 'Datascientist, Jane' }], trim_highlights(result)
  end

  test 'parse_geo_dates returns issued over coverage' do
    dates = [{ 'kind' => 'Coverage', 'value' => '2009-01-01' },
             { 'kind' => 'Issued', 'value' => '2011' }]
    assert_equal '2011', parse_geo_dates(dates)
  end

  test 'parse_geo_dates returns coverage if issued is not available' do
    dates = [{ 'kind' => 'Coverage', 'value' => '2009' }]
    assert_equal '2009', parse_geo_dates(dates)
  end

  test 'parse_geo_dates ignores types that are not coverage or issued' do
    dates = [{ 'kind' => 'Created', 'value' => '2009-01-01' },
             { 'kind' => 'Published', 'value' => '2011' }]
    assert_nil parse_geo_dates(dates)
  end

  test 'parse_geo_dates returns simple years as-is' do
    dates = [{ 'kind' => 'Coverage', 'value' => '1999' }]
    assert_equal '1999', parse_geo_dates(dates)
  end

  test 'parse_geo_dates handles reasonable permutations of YYYY-MM' do
    yyyy_mm = [{ 'kind' => 'Issued', 'value' => '2017-02' }]
    mm_yyyy = [{ 'kind' => 'Issued', 'value' => '02-2017' }]
    yyyy_slash = [{ 'kind' => 'Issued', 'value' => '2017/02' }]
    slash_yyyy = [{ 'kind' => 'Issued', 'value' => '02/2017' }]
    assert_equal '2017', parse_geo_dates(yyyy_mm)
    assert_equal '2017', parse_geo_dates(mm_yyyy)
    assert_equal '2017', parse_geo_dates(yyyy_slash)
    assert_equal '2017', parse_geo_dates(slash_yyyy)
  end

  test 'parse_geo_dates handles reasonable permutations of MM/DD/YYYY' do
    mm_dd_yyyy = [{ 'kind' => 'Issued', 'value' => '10-24-2015' }]
    dd_mm_yyyy = [{ 'kind' => 'Issued', 'value' => '24-10-2015' }]
    yyyy_mm_dd = [{ 'kind' => 'Issued', 'value' => '2015-10-05' }]
    yyyy_dd_mm = [{ 'kind' => 'Issued', 'value' => '2015-05-10' }]
    assert_equal '2015', parse_geo_dates(mm_dd_yyyy)
    assert_equal '2015', parse_geo_dates(dd_mm_yyyy)
    assert_equal '2015', parse_geo_dates(yyyy_mm_dd)
    assert_equal '2015', parse_geo_dates(yyyy_dd_mm)
  end

  test 'parse_geo_dates extracts year from parsable dates' do
    mm_dd_yyyy = [{ 'kind' => 'Issued', 'value' => '10/24/2015' }]
    dd_mm_yyyy = [{ 'kind' => 'Issued', 'value' => '24/10/2015' }]
    yyyy_mm_dd = [{ 'kind' => 'Issued', 'value' => '2015/10/05' }]
    yyyy_dd_mm = [{ 'kind' => 'Issued', 'value' => '2015/05/10' }]
    assert_equal '2015', parse_geo_dates(mm_dd_yyyy)
    assert_equal '2015', parse_geo_dates(dd_mm_yyyy)
    assert_equal '2015', parse_geo_dates(yyyy_mm_dd)
    assert_equal '2015', parse_geo_dates(yyyy_dd_mm)
  end

  test 'parse_geo_dates returns nil for garbage dates' do
    wtf = [{ 'kind' => 'Issued', 'value' => '10/2015/24' }]
    omg = [{ 'kind' => 'Issued', 'value' => 'foo' }]
    assert_nil parse_geo_dates(wtf)
    assert_nil parse_geo_dates(omg)
  end

  # The goal here is not test every possible field name, but to confirm enough of a variety that we can infer that all
  # of them will be parsed appropriately.
  test 'highlight field names are humanized' do
    subjects_value = 'subjects.value'
    alternate_titles = 'alternateTitle.value'
    funding_information_name = 'fundingInformation.funderName'
    date_range = 'dates.range'
    edition = 'edition'
    assert_equal 'Subjects', format_highlight_label(subjects_value)
    assert_equal 'Alternate title', format_highlight_label(alternate_titles)
    assert_equal 'Funding information', format_highlight_label(funding_information_name)
    assert_equal 'Dates', format_highlight_label(date_range)
    assert_equal 'Edition', format_highlight_label(edition)
  end

  test 'applied_keyword translates q param' do
    query = {
      q: 'usability'
    }
    assert_equal ['Keyword anywhere: usability'], applied_keyword(query)
  end

  test 'applied_geobox_terms includes and translates all geobox params' do
    query = {
      geobox: true,
      geoboxMinLatitude: '41.2',
      geoboxMaxLatitude: '42.9',
      geoboxMinLongitude: '-73.5',
      geoboxMaxLongitude: '-69.9'
    }
    assert_equal ['Min latitude: 41.2', 'Max latitude: 42.9', 'Min longitude: -73.5', 'Max longitude: -69.9'],
                 applied_geobox_terms(query)
  end

  test 'applied_geodistance_terms includes and translates all geodistance params' do
    query = {
      geodistance: true,
      geodistanceLatitude: '42.3',
      geodistanceLongitude: '-83.7',
      geodistanceDistance: '50mi'
    }
    assert_equal ['Latitude: 42.3', 'Longitude: -83.7', 'Distance: 50mi'], applied_geodistance_terms(query)
  end

  test 'applied_advanced_terms includes all possible advanced search terms' do
    query = {
      title: 'sample book',
      citation: 'person, sample. sample book. someplace, 2024',
      contributors: 'person, sample',
      fundingInformation: 'imls',
      identifiers: '1234/5678',
      locations: 'someplace',
      subjects: 'unit testing'
    }
    assert_equal ['Title: sample book', 'Citation: person, sample. sample book. someplace, 2024',
                  'Contributors: person, sample', 'Funding information: imls', 'Identifiers: 1234/5678',
                  'Locations: someplace', 'Subjects: unit testing'], applied_advanced_terms(query)
  end

  test 'applied_advanced_terms translates contributors in GeoData' do
    ClimateControl.modify FEATURE_GEODATA: 'true' do
      query = {
        contributors: 'person, sample'
      }
      assert_equal ['Authors: person, sample'], applied_advanced_terms(query)
    end
  end

  test 'link_to_result returns link when source_link is present' do
    result = {
      title: 'Sample Document Title',
      source_link: 'https://example.com/document'
    }
    expected_link = '<a href="https://example.com/document">Sample Document Title</a>'
    assert_equal expected_link, link_to_result(result)
  end

  test 'link_to_result returns plain title when source_link is nil' do
    result = {
      title: 'Sample Document Title',
      source_link: nil
    }
    assert_equal 'Sample Document Title', link_to_result(result)
  end

  test 'link_to_result returns plain title when source_link is empty string' do
    result = {
      title: 'Sample Document Title',
      source_link: ''
    }
    assert_equal 'Sample Document Title', link_to_result(result)
  end

  test 'link_to_result returns plain title when source_link key is absent' do
    result = {
      title: 'Sample Document Title'
    }
    assert_equal 'Sample Document Title', link_to_result(result)
  end

  test 'link_to_tab builds a link without an aria attribute when that tab is not active' do
    @active_tab = 'bar'
    actual = link_to_tab('Foo')

    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_select '[class*=?]', 'active', count: 0
      assert_select '[class*=?]', 'tab-link'
      assert_select '[aria-current=?]', 'page', count: 0
    end
  end

  test 'link_to_tab builds a link that includes an aria attribute when that tab is active' do
    @active_tab = 'foo'
    actual = link_to_tab('Foo')

    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_select link, '[class*=?]', 'active'
      assert_select link, '[aria-current=?]', 'page', count: 1
    end
  end

  test 'primo_search_url generates correct Primo URL' do
    query = 'machine learning'
    expected_url = 'https://mit.primo.exlibrisgroup.com/discovery/search?query=any%2Ccontains%2Cmachine+learning&vid=01MIT_INST%3AMIT'
    assert_equal expected_url, primo_search_url(query)
  end

  test 'primo_search_url handles special characters in query' do
    query = 'data & analytics'
    expected_url = 'https://mit.primo.exlibrisgroup.com/discovery/search?query=any%2Ccontains%2Cdata+%26+analytics&vid=01MIT_INST%3AMIT'
    assert_equal expected_url, primo_search_url(query)
  end

  test 'tab label defaults to target when label is nil' do
    @active_tab = 'sample_tab'
    actual = link_to_tab('Sample Tab', nil)
    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_equal link.text, 'Sample Tab'
    end
  end

  test 'tab label uses label when label is provided' do
    @active_tab = 'sample_tab'
    actual = link_to_tab('Sample Tab', 'Custom Label')
    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_equal link.text, 'Custom Label'
    end
  end

  test 'tab param uses clean_target when label is nil' do
    @active_tab = 'sample_tab'
    actual = link_to_tab('Sample Tab', nil)
    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_equal link.first[:href], '/results?tab=sample_tab'
    end
  end

  test 'tab param uses clean_target when label is provided' do
    @active_tab = 'sample_tab'
    actual = link_to_tab('Sample Tab', 'Custom Label')
    assert_select Nokogiri::HTML::Document.parse(actual), 'a' do |link|
      assert_equal link.first[:href], '/results?tab=sample_tab'
    end
  end
end
