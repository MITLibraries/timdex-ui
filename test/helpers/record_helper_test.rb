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
                   'description' => 'no authentication required',
                   'kind' => 'Access to files'
                 }
               ]
             }
    assert_equal 'no authentication required', access_type(rights)
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
                            'description' => 'no authentication required',
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
                             'description' => 'unknown: check with owning institution',
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
                        'description' => 'no authentication required',
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
                        'description' => 'MIT authentication required',
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

  test 'more_info_geo? true if some relevant fields exist' do
    date_record = { 'dates' => [{ 'kind' => 'Issued', 'value' => '2001' }] }
    assert more_info_geo?(date_record)

    locations_record = { 'locations' => [{ 'kind' => 'Place Name', 'value' => 'The Village Vanguard' }] }
    assert more_info_geo?(locations_record)

    provider_record = { 'provider' => 'MIT' }
    assert more_info_geo?(provider_record)
  end

  test 'more_info_geo? false if no more info available' do
    record = { 'title' => 'foo', 'source' => 'bar' }
    assert_not more_info_geo?(record)
  end

  test 'parse_nested_field returns nil for fields that are not nested' do
    string_field = 'string'
    array_of_strings_field = ['string', 'other_string']
    assert_nil parse_nested_field(string_field)
    assert_nil parse_nested_field(array_of_strings_field)
  end

  test 'parse_nested_field returns something for fields that seem nested' do
    nested_field = [{ 'foo' => 'bar' }]
    assert_equal nested_field, parse_nested_field(nested_field)
  end

  test 'parse_nested_field ignores mitAffiliated subfield' do
    contributors = [{ 'kind' => 'bandleader', 'value' => 'Coltrane, John', 'mitAffiliated' => false }]
    assert_equal [{ 'kind' => 'bandleader', 'value' => 'Coltrane, John' }], parse_nested_field(contributors)
  end

  test 'parse_nested_field trims null values' do
    contributors = [{ 'kind' => 'bandleader', 'value' => 'Coltrane, John', 'identifier' => nil }]
    assert_equal [{ 'kind' => 'bandleader', 'value' => 'Coltrane, John' }], parse_nested_field(contributors)
  end

  test 'render_subfield treats date ranges accordingly' do
    date_range = { 'kind' => 'Coverage', 'value' => '1999', 'range' => { 'gte' => '1999', 'lte' => '2000' } }
    assert_equal "kind: Coverage; range: 1999 to 2000", render_subfield(date_range)
  end

  test 'render_subfield renders a variety of key/value pairs' do
    contributor = { 'kind' => 'bandleader', 'value' => 'Coltrane, John', 'identifier' => 'Trane', 'genre' => 'jazz' }
    assert_equal "kind: bandleader; value: Coltrane, John; identifier: Trane; genre: jazz", render_subfield(contributor)
  end
end
