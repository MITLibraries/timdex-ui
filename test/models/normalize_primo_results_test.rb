require 'test_helper'

class NormalizePrimoResultsTest < ActiveSupport::TestCase
  def sample_results
    {
      'docs' => [
        JSON.parse(File.read(Rails.root.join('test/fixtures/primo/full_record.json'))),
        JSON.parse(File.read(Rails.root.join('test/fixtures/primo/minimal_record.json')))
      ],
      'info' => {
        'total' => 10
      }
    }
  end

  def empty_results
    {
      'docs' => [],
      'info' => {
        'total' => 0
      }
    }
  end

  test 'normalizes multiple records' do
    normalizer = NormalizePrimoResults.new(sample_results, 'test query')
    normalized = normalizer.normalize

    assert_equal 2, normalized.length
    assert_equal 'Testing the Limits of Knowledge', normalized.first[:title]
    assert_equal 'unknown title', normalized.second[:title]
  end

  test 'handles empty results' do
    normalizer = NormalizePrimoResults.new(empty_results, 'test query')
    normalized = normalizer.normalize

    assert_empty normalized
  end

  test 'handles nil results' do
    normalizer = NormalizePrimoResults.new(nil, 'test query')
    normalized = normalizer.normalize

    assert_empty normalized
  end

  test 'handles results without docs' do
    results_without_docs = { 'info' => { 'total' => 0 } }
    normalizer = NormalizePrimoResults.new(results_without_docs, 'test query')
    normalized = normalizer.normalize

    assert_empty normalized
  end

  test 'returns total results count' do
    normalizer = NormalizePrimoResults.new(sample_results, 'test query')
    assert_equal 10, normalizer.total_results
  end

  test 'returns zero for total results when no info' do
    normalizer = NormalizePrimoResults.new({ 'docs' => [] }, 'test query')
    assert_equal 0, normalizer.total_results
  end

  test 'returns zero for total results when nil results' do
    normalizer = NormalizePrimoResults.new(nil, 'test query')
    assert_equal 0, normalizer.total_results
  end
end
