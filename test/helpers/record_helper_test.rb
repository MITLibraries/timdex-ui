require 'test_helper'

class RecordHelperTest < ActionView::TestCase
  include RecordHelper

  # Display formatters
  test 'render_key converts keys into human readable values' do
    assert_equal 'Simple', render_key('Simple')
    assert_equal 'Simple', render_key('simple')
    assert_equal 'Two words', render_key('two_words')
  end

  # Field type helpers
  # - Lists
  test 'field_list returns nothing if the element does not exist' do
    sample = {}
    assert_nil field_list(sample, 'none')
  end

  test 'field_list returns a single key name and value with one element' do
    sample = {}
    sample['foo'] = ['bar']
    assert_equal "<h3>Foo</h3><p class='field-list'>bar</p>", field_list(sample, 'foo')
  end

  test 'field_list returns a key name and a list of values with multiple elements' do
    sample = {}
    sample['foo'] = %w[bar baz]
    assert_equal "<h3>Foo</h3><ul class='field-list'><li>bar</li><li>baz</li></ul>", field_list(sample, 'foo')
  end

  # - Objects of kind and value
  test 'field_object returns nil if the element does not exist' do
    sample = {}
    assert_nil field_object(sample, 'none')
  end

  test 'field_object returns a list of kind/value pairs' do
    sample_item = {}
    sample_item['kind'] = 'DOI'
    sample_item['value'] = '10.7910/DVN/48GFKU'
    sample = { 'identifiers' => [sample_item] }
    assert_equal "<h3>Identifiers</h3><ul class='field-object'><li>DOI: 10.7910/DVN/48GFKU</li></ul>",
                 field_object(sample, 'identifiers')
    sample = { 'identifiers' => [sample_item, sample_item] }
    assert_equal "<h3>Identifiers</h3><ul class='field-object'><li>DOI: 10.7910/DVN/48GFKU</li><li>DOI: 10.7910/DVN/48GFKU</li></ul>",
                 field_object(sample, 'identifiers')
  end

  test 'field_object can deal with lists of values' do
    sample_item = {}
    sample_item['kind'] = 'food'
    # List of one item
    sample_item['value'] = ['loaf of bread']
    sample = { 'shopping' => [sample_item] }
    assert_equal "<h3>Shopping</h3><ul class='field-object'><li>food: loaf of bread</li></ul>",
                 field_object(sample, 'shopping')

    sample_item['value'] = ['loaf of bread', 'container of milk', 'stick of butter']
    sample = { 'shopping' => [sample_item] }
    assert_equal "<h3>Shopping</h3><ul class='field-object'><li>food: <ul><li>loaf of bread</li><li>container of milk</li><li>stick of butter</li></ul></li></ul>",
                 field_object(sample, 'shopping')
  end

  # - Strings
  test 'field_string returns nil if the element does not exist' do
    sample = {}
    assert_nil field_string(sample, 'none')
  end

  test 'field_string returns a key name and value in HTML' do
    sample = {}
    sample['foo'] = 'lowercase'
    assert_equal "<h3>Foo</h3><p class='field-string'>lowercase</p>", field_string(sample, 'foo')
    sample['foo'] = 'Capitalized'
    assert_equal "<h3>Foo</h3><p class='field-string'>Capitalized</p>", field_string(sample, 'foo')
  end

  # - Tables
  test 'field_table returns nil if the element does not exist' do
    sample = {}
    assert_nil field_table(sample, 'none', %w[foo bar baz])
  end

  test 'field_table returns a table of information' do
    sample_item = {}
    sample_item['foo'] = 'column'
    sample_item['bar'] = 'custom'
    sample_item['baz'] = 'order'
    sample = { 'construct' => [sample_item] }
    assert_equal "<h3>Construct</h3><table><thead><tr><th scope='col'>Bar</th><th scope='col'>Foo</th><th scope='col'>Baz</th></tr></thead><tbody><tr><td>custom</td><td>column</td><td>order</td></tr></tbody></table>",
                 field_table(sample, 'construct', %w[bar foo baz])
  end

  test 'field_table returns a table of information using provided label' do
    sample_item = {}
    sample_item['foo'] = 'column'
    sample_item['bar'] = 'custom'
    sample_item['baz'] = 'order'
    sample = { 'construct' => [sample_item] }
    assert_equal "<h3>Hello I am a label</h3><table><thead><tr><th scope='col'>Bar</th><th scope='col'>Foo</th><th scope='col'>Baz</th></tr></thead><tbody><tr><td>custom</td><td>column</td><td>order</td></tr></tbody></table>",
                 field_table(sample, 'construct', %w[bar foo baz], 'Hello I am a label')
  end

  test 'access_type returns nil if corresponding right is blank' do
    rights = { 
               'rights' => [
                 {
                   'description' => 'foo',
                   'kind' => 'bar'
                 }
               ]
             }
    assert_nil access_type(rights)
  end

  test 'access_type returns the description of the corresponding right' do
    rights = {
               'rights' => [
                 {
                   'description' => 'foo',
                   'kind' => 'bar'
                 },
                 {
                   'description' => 'Free/open to all',
                   'kind' => 'Access to files'
                 }
               ]
             }
    assert_equal 'Free/open to all', access_type(rights)
  end

  test 'gis_access_link returns nil if access type is blank' do
    links_no_rights = {
                        'links' => [
                          {
                            'kind' => 'Download',
                            'text' => 'Data',
                            'url' => 'https://example.org/dz_f7regions_2016.zip'
                          },
                          {
                            'kind' => 'Website',
                            'text' => 'Website',
                            'url' => 'https://example.org/gismit:dz_f7regions_2016'
                          }
                        ]
                      }
    assert_nil access_type(links_no_rights)
    assert_nil gis_access_link(links_no_rights)
  end

  test 'gis_access_link returns nil if links are blank' do
    rights_no_links = {
                        'rights' => [
                          {
                            'description' => 'foo',
                            'kind' => 'bar'
                          },
                          {
                            'description' => 'Free/open to all',
                            'kind' => 'Access to files'
                          }
                        ]
                      }
    assert_nil gis_access_link(rights_no_links)
  end

  test 'gis_access_link is website URL for non-MIT records' do
    access_elsewhere = {
                         'rights' => [
                           {
                             'description' => 'foo',
                             'kind' => 'bar'
                           },
                           {
                             'description' => 'Not owned by MIT',
                             'kind' => 'Access to files'
                           }
                         ],
                         'links' => [
                           {
                             'kind' => 'Download',
                             'text' => 'Data',
                             'url' => 'https://example.org/dz_f7regions_2016.zip'
                           },
                           {
                             'kind' => 'Website',
                             'text' => 'Website',
                             'url' => 'https://example.org/gismit:dz_f7regions_2016'
                           }
                         ],
                         'provider' => 'Spelman'
                       }
    assert_equal 'https://example.org/gismit:dz_f7regions_2016', gis_access_link(access_elsewhere)
  end

  test 'gis_access_link is data download URL for MIT records' do
    access_free = {
                    'rights' => [
                      {
                        'description' => 'foo',
                        'kind' => 'bar'
                      },
                      {
                        'description' => 'Free/open to all',
                        'kind' => 'Access to files'
                      }
                    ],
                    'links' => [
                      {
                        'kind' => 'Download',
                        'text' => 'Data',
                        'url' => 'https://example.org/dz_f7regions_2016.zip'
                      },
                      {
                        'kind' => 'Website',
                        'text' => 'Website',
                        'url' => 'https://example.org/gismit:dz_f7regions_2016'
                      }
                    ]
                  }
    access_auth = {
                    'rights' => [
                      {
                        'description' => 'foo',
                        'kind' => 'bar'
                      },
                      {
                        'description' => 'MIT authenticated',
                        'kind' => 'Access to files'
                      }
                    ],
                    'links' => [
                      {
                        'kind' => 'Download',
                        'text' => 'Data',
                        'url' => 'https://example.org/dz_f7regions_2016.zip'
                      },
                      {
                        'kind' => 'Website',
                        'text' => 'Website',
                        'url' => 'https://example.org/gismit:dz_f7regions_2016'
                      }
                    ]
                  }
    assert_equal 'https://example.org/dz_f7regions_2016.zip', gis_access_link(access_free)
    assert_equal 'https://example.org/dz_f7regions_2016.zip', gis_access_link(access_auth)
  end

  test 'issued_dates returns all issued dates' do
    dates = [{ 'kind' => 'Issued', 'value' => '1-1-1999' },
             { 'kind' => 'Issued', 'value' => '1-1-1997' }]
    assert_equal ('1-1-1999; 1-1-1997'), issued_dates(dates)
  end

  test 'issued_dates does not return dates of other kinds' do
    dates = [{ 'kind' => 'Birthday', 'value' => '1-1-1999' },
             { 'kind' => 'First', 'value' => '1' },
             { 'kind' => 'Coverage', 'value' => '1949' }]
    assert_nil issued_dates(dates)
  end

  test 'issued_dates handles ranges' do
    dates = [{ 'kind' => 'Issued', 'range' => { 'gte' => '2000', 'lte' => '2001' }},
             { 'kind' => 'Issued', 'range' => { 'gte' => '1999', 'lte' => '1999' }}]
    assert_equal '2000-2001; 1999', issued_dates(dates)
  end

  test 'issued_dates handles duplicate dates' do
    dates = [{ 'kind' => 'Issued', 'value' => '1999' },
             { 'kind' => 'Issued', 'value' => '1999' },
             { 'kind' => 'Issued', 'range' => { 'gte' => '1999', 'lte' => '1999' }}]
    assert_equal '1999', issued_dates(dates)
  end

  test 'issued_dates returns nil if no dates are available' do
    dates = []
    assert_nil issued_dates(dates)
  end

  test 'coverage_dates returns all coverage dates' do
    dates = [{ 'kind' => 'Coverage', 'value' => '1999' },
             { 'kind' => 'Coverage', 'value' => '1997' }]
    assert_equal ('1999; 1997'), coverage_dates(dates)
  end

  test 'coverage_dates does not return dates of other kinds' do
    dates = [{ 'kind' => 'Birthday', 'value' => '1-1-1999' },
             { 'kind' => 'First', 'value' => '1' },
             { 'kind' => 'Issued', 'value' => '1949' }]
    assert_nil coverage_dates(dates)
  end

  test 'coverage_dates handles ranges' do
    dates = [{ 'kind' => 'Coverage', 'range' => { 'gte' => '2000', 'lte' => '2001' }},
             { 'kind' => 'Coverage', 'range' => { 'gte' => '1999', 'lte' => '1999' }}]
    assert_equal '2000-2001; 1999', coverage_dates(dates)
  end

  test 'coverage_dates handles duplicate dates' do
    dates = [{ 'kind' => 'Coverage', 'value' => '1999' },
             { 'kind' => 'Coverage', 'value' => '1999' },
             { 'kind' => 'Coverage', 'range' => { 'gte' => '1999', 'lte' => '1999' }}]
    assert_equal '1999', coverage_dates(dates)
  end

  test 'coverage_dates returns nil if no dates are available' do
    dates = []
    assert_nil coverage_dates(dates)
  end

  test 'source_metadata_available? returns true if source metadata link exists' do
    links = [{ 'kind' => 'Download', 'text' => 'Source Metadata', 'url' => 'https://example.org/metadata.zip' }]
    assert source_metadata_available?(links)
  end

  test 'source_metadata_available? returns false if no source metadata link exists' do
    links = [{ 'kind' => 'Download', 'text' => 'Sauce Metadata', 'url' => 'https://example.org/metadata.zip' }]
    no_links = []
    assert_not source_metadata_available?(links)
    assert_not source_metadata_available?(no_links)
  end

  test 'source_metadata_link returns nil if no links are available' do
    no_links = []
    assert_nil source_metadata_link(no_links)
  end

  test 'source_metadata_link returns the right link' do
    links = [{ 'kind' => 'Download', 'text' => 'Source Metadata', 'url' => 'https://example.org/metadata.zip' },
             { 'kind' => 'Download', 'text' => 'Sauce Metadata', 'url' => 'https://example.org/meatdata.zarp' }]
    assert_equal 'https://example.org/metadata.zip', source_metadata_link(links)
  end

  test 'places collects place names only' do
    locations = [{ 'kind' => 'Place Name', 'value' => 'The Village Vanguard' },
                 { 'kind' => 'Place Name', 'value' => 'Birdland' },
                 { 'kind' => 'geopoint', 'value' => 'foo' }]
    assert_equal ['The Village Vanguard', 'Birdland'], places(locations)
  end

  test 'places returns nil if no place names are present' do
    locations = [{ 'kind' => 'geopoint', 'value' => 'foo' }]
    assert_nil places(locations)
  end

  test 'more_info? true with issued_dates' do
    record = { 'dates' => [{ 'kind' => 'Issued', 'value' => '2001' }] }
    assert more_info?(record)
  end

  test 'more_info? true with coverage_dates' do
    record = { 'dates' => [{ 'kind' => 'Coverage', 'value' => '2001' }] }
    assert more_info?(record)
  end

  test 'more_info? true with places' do
    record = { 'locations' => [{ 'kind' => 'Place Name', 'value' => 'The Village Vanguard' }] }
    assert more_info?(record)
  end

  test 'more_info? true with provider' do
    record = { 'provider' => 'MIT' }
    assert more_info?(record)
  end

  test 'more_info? false if no more info available' do
    record = { 'title' => 'foo', 'source' => 'bar' }
    assert_not more_info?(record)
  end
end
