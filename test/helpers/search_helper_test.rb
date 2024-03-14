require 'test_helper'

class SearchHelperTest < ActionView::TestCase
  include SearchHelper

  test 'removes displayed fields from highlights' do
    result = { 'highlight' => [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                               { 'matchedField' => 'title.exact_value', 'matchedPhrases' => 'Very important data' },
                               { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                               { 'matchedField' => 'dates.value', 'matchedPhrases' => '2022' },
                               { 'matchedField' => 'contributors.value', 'matchedPhrases' => 'Jane Datascientist' }] }
    assert_empty trim_highlights(result)
  end

  test 'does not remove undisplayed fields from highlights' do
    result = { 'highlight' => [{ 'matchedField' => 'summary', 'matchedPhrases' => 'Have some data' }] }
    assert_equal [{ 'matchedField' => 'summary', 'matchedPhrases' => 'Have some data' }], trim_highlights(result)
  end

  test 'returns correct set of highlights when result includes displayed and undisplayed fields' do
    result = { 'highlight' => [{ 'matchedField' => 'title', 'matchedPhrases' => 'Very important data' },
                               { 'matchedField' => 'content_type', 'matchedPhrases' => 'Dataset' },
                               { 'matchedField' => 'summary', 'matchedPhrases' => '2022' },
                               { 'matchedField' => 'citation', 'matchedPhrases' => 'Datascientist, Jane' }] }
    assert_equal [{ 'matchedField' => 'summary', 'matchedPhrases' => '2022' },
                  { 'matchedField' => 'citation', 'matchedPhrases' => 'Datascientist, Jane' }], trim_highlights(result)
  end

  test 'renders view_online link if sourceLink is present' do
    result = { 'title' => 'A record', 'sourceLink' => 'https://example.org' }
    assert_equal '<a class="button button-primary green" href="https://example.org">View online</a>',
                 view_online(result)
  end

  test 'does not render view_online link if sourceLink is absent' do
    result = { 'title' => 'A record' }
    assert_nil view_online(result)
  end

  test 'parse_geo_dates returns issued over coverage' do
    dates = [{ 'kind' => 'Coverage', 'value' => '2009-01-01' },
             { 'kind' => 'Issued', 'value' => '2011' }]
    assert_equal '2011', parse_geo_dates(dates)
  end

  test 'parse_geo_dates returns issued if coverage is not available' do
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
end
