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

  test 'all primo results includes primo as source api' do
    normalizer = NormalizePrimoResults.new(sample_results, 'test query')
    normalized = normalizer.normalize

    normalized.each do |result|
      assert_equal 'primo', result[:api]
    end
  end

  test 'preserves frbr group ids on their normalized records' do
    normalizer = NormalizePrimoResults.new(sample_results, 'test query')
    normalized = normalizer.normalize

    assert_equal '12345', normalized.first[:frbr_group_id]
    assert_nil normalized.second[:frbr_group_id]
  end

  test 'collects only Alma frbr groups from mixed results' do
    docs = %w[alma_record cdi_record].map do |fixture|
      JSON.parse(File.read(Rails.root.join("test/fixtures/primo/#{fixture}.json")))
    end
    normalizer = NormalizePrimoResults.new({ 'docs' => docs }, 'test')
    normalized = normalizer.normalize

    assert_equal 'alma12345', normalized.first[:frbr_group_id]
    assert_nil normalized.second[:frbr_group_id]
  end

  test 'does not collect frbr groups when record source is unknown' do
    record = JSON.parse(File.read(Rails.root.join('test/fixtures/primo/alma_record.json')))
    record['pnx']['control'].delete('recordid')
    normalizer = NormalizePrimoResults.new({ 'docs' => [record] }, 'test')
    assert_nil normalizer.normalize.first[:frbr_group_id]
  end

  test 'does not collect frbr group ids for non-frbrized records' do
    record = JSON.parse(File.read(Rails.root.join('test/fixtures/primo/full_record.json')))
    record['pnx']['facets']['frbrtype'] = ['3']
    record['pnx']['facets']['frbrgroupid'] = ['should_not_log']
    results = { 'docs' => [record], 'info' => { 'total' => 1 } }

    normalizer = NormalizePrimoResults.new(results, 'test query')
    assert_nil normalizer.normalize.first[:frbr_group_id]
  end

  test 'collects only Alma groups when CDI records have matching grouping fields' do
    alma = sample_results['docs'].first
    alma['pnx']['control']['recordid'] = ['alma123']
    alma['pnx']['facets']['frbrtype'] = ['5']
    alma['pnx']['facets']['frbrgroupid'] = ['alma-group']
    cdi = alma.deep_dup
    cdi['pnx']['control']['recordid'] = ['cdi_example_456']
    cdi['pnx']['facets']['frbrgroupid'] = ['cdi-dedup-group']

    normalizer = NormalizePrimoResults.new({ 'docs' => [alma, cdi] }, 'test query')
    normalized = normalizer.normalize

    assert_equal 2, normalized.length
    assert_equal 'alma-group', normalized.first[:frbr_group_id]
    assert_nil normalized.second[:frbr_group_id]
  end

  test 'does not collect groups without an Alma record identifier' do
    record = sample_results['docs'].first
    record['pnx']['control'].delete('recordid')
    normalizer = NormalizePrimoResults.new({ 'docs' => [record] }, 'test query')
    assert_nil normalizer.normalize.first[:frbr_group_id]
  end

  test 'omits blank or ambiguous FRBR group IDs' do
    record = sample_results['docs'].first
    [nil, [], [' '], %w[group-a group-b]].each do |group_ids|
      record['pnx']['facets']['frbrgroupid'] = group_ids
      normalized = NormalizePrimoResults.new({ 'docs' => [record] }, 'test query').normalize

      assert_nil normalized.first[:frbr_group_id]
    end
  end
end
