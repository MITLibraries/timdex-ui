require 'test_helper'

class NormalizeTimdexResultsTest < ActiveSupport::TestCase
  def sample_timdex_response
    [
      JSON.parse(File.read(Rails.root.join('test/fixtures/timdex/full_record.json'))),
      JSON.parse(File.read(Rails.root.join('test/fixtures/timdex/minimal_record.json')))
    ]
  end

  def empty_timdex_response
    []
  end

  test 'normalizes TIMDEX response with records' do
    normalizer = NormalizeTimdexResults.new(sample_timdex_response, 'test query')
    results = normalizer.normalize

    assert_equal 2, results.count

    # Check first record (full record)
    first_result = results.first
    assert_equal 'Sample TIMDEX Record for Testing', first_result[:title]
    assert_equal 'test-record-123', first_result[:identifier]
    assert_equal 'Test Repository', first_result[:source]
    assert_equal 'Dataset ; Geospatial data', first_result[:format]
    assert_equal '2023', first_result[:year]

    # Check TIMDEX-specific fields are preserved
    assert_includes first_result.keys, :content_type
    assert_includes first_result.keys, :dates
    assert_includes first_result.keys, :contributors
    assert_includes first_result.keys, 'highlight'
    assert_includes first_result.keys, 'source_link'

    # Check second record (minimal record)
    second_result = results.second
    assert_equal 'Minimal Test Record', second_result[:title]
    assert_equal 'minimal-record-456', second_result[:identifier]
    assert_equal 'Test Repository', second_result[:source]
  end

  test 'handles empty TIMDEX response' do
    normalizer = NormalizeTimdexResults.new(empty_timdex_response, 'test query')
    results = normalizer.normalize

    assert_empty results
  end

  test 'handles nil TIMDEX response' do
    normalizer = NormalizeTimdexResults.new(nil, 'test query')
    results = normalizer.normalize

    assert_empty results
  end

  test 'handles response without data field' do
    invalid_response = { 'errors' => ['Some error'] }
    normalizer = NormalizeTimdexResults.new(invalid_response, 'test query')
    results = normalizer.normalize

    assert_empty results
  end

  test 'handles response without search field' do
    invalid_response = { 'data' => { 'other' => 'data' } }
    normalizer = NormalizeTimdexResults.new(invalid_response, 'test query')
    results = normalizer.normalize

    assert_empty results
  end

  test 'handles response without records field' do
    invalid_response = { 'data' => { 'search' => { 'other' => 'data' } } }
    normalizer = NormalizeTimdexResults.new(invalid_response, 'test query')
    results = normalizer.normalize

    assert_empty results
  end

  test 'preserves query in normalizer' do
    query = 'test search query'
    normalizer = NormalizeTimdexResults.new(sample_timdex_response, query)

    # Test that query is stored (this would be used by individual record normalization)
    assert_equal query, normalizer.instance_variable_get(:@query)
  end
end
