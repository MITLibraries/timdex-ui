require 'test_helper'

class RecordHelperTest < ActionView::TestCase
  include RecordHelper

  # Display formatters
  test 'render_field converts keys into human readable values' do
    assert_equal 'Simple', render_field('Simple')
    assert_equal 'Simple', render_field('simple')
    assert_equal 'Two words', render_field('two_words')
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
    assert_equal "<h2>Foo</h2><p class='field-list'>bar</p>", field_list(sample, 'foo')
  end

  test 'field_list returns a key name and a list of values with multiple elements' do
    sample = {}
    sample['foo'] = %w[bar baz]
    assert_equal "<h2>Foo</h2><ul class='field-list'><li>bar</li><li>baz</li></ul>", field_list(sample, 'foo')
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
    assert_equal "<h2>Identifiers</h2><ul class='field-object'><li>DOI: 10.7910/DVN/48GFKU</li></ul>",
                 field_object(sample, 'identifiers')
    sample = { 'identifiers' => [sample_item, sample_item] }
    assert_equal "<h2>Identifiers</h2><ul class='field-object'><li>DOI: 10.7910/DVN/48GFKU</li><li>DOI: 10.7910/DVN/48GFKU</li></ul>",
                 field_object(sample, 'identifiers')
  end

  test 'field_object can deal with lists of values' do
    sample_item = {}
    sample_item['kind'] = 'food'
    # List of one item
    sample_item['value'] = ['loaf of bread']
    sample = { 'shopping' => [sample_item] }
    assert_equal "<h2>Shopping</h2><ul class='field-object'><li>food: loaf of bread</li></ul>",
                 field_object(sample, 'shopping')

    sample_item['value'] = ['loaf of bread', 'container of milk', 'stick of butter']
    sample = { 'shopping' => [sample_item] }
    assert_equal "<h2>Shopping</h2><ul class='field-object'><li>food: <ul><li>loaf of bread</li><li>container of milk</li><li>stick of butter</li></ul></li></ul>",
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
    assert_equal "<h2>Foo</h2><p class='field-string'>lowercase</p>", field_string(sample, 'foo')
    sample['foo'] = 'Capitalized'
    assert_equal "<h2>Foo</h2><p class='field-string'>Capitalized</p>", field_string(sample, 'foo')
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
    assert_equal "<h2>Construct</h2><table><thead><tr><th scope='col'>Bar</th><th scope='col'>Foo</th><th scope='col'>Baz</th></tr></thead><tbody><tr><td>custom</td><td>column</td><td>order</td></tr></tbody></table>",
                 field_table(sample, 'construct', %w[bar foo baz])
  end
end
