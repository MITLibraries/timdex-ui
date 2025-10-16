require 'test_helper'

class NormalizeTimdexRecordTest < ActiveSupport::TestCase
  def full_record
    JSON.parse(File.read(Rails.root.join('test/fixtures/timdex/full_record.json')))
  end

  def minimal_record
    JSON.parse(File.read(Rails.root.join('test/fixtures/timdex/minimal_record.json')))
  end

  test 'normalizes title' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'Sample TIMDEX Record for Testing', normalized['title']
  end

  test 'handles missing title' do
    record_without_title = minimal_record
    record_without_title.delete('title')
    normalized = NormalizeTimdexRecord.new(record_without_title, 'test').normalize
    assert_equal 'Unknown title', normalized['title']
  end

  test 'normalizes creators from contributors' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_creators = [
      { 'value' => 'Smith, Jane', 'link' => nil },
      { 'value' => 'Doe, John', 'link' => nil }
    ]
    assert_equal expected_creators, normalized['creators']
  end

  test 'handles missing creators' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['creators']
  end

  test 'normalizes source' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'Test Repository', normalized['source']
  end

  test 'handles missing source' do
    record_without_source = minimal_record.dup
    record_without_source.delete('source')
    normalized = NormalizeTimdexRecord.new(record_without_source, 'test').normalize
    assert_equal 'Unknown source', normalized['source']
  end

  test 'extracts year from publication date' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal '2023', normalized['year']
  end

  test 'handles missing year' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['year']
  end

  test 'extracts year from fallback date when no publication date' do
    record_with_coverage_date = minimal_record.dup
    record_with_coverage_date['dates'] = [
      { 'kind' => 'Coverage', 'value' => '1995-2000' },
      { 'kind' => 'Creation', 'value' => 'Created in 1998' }
    ]
    normalized = NormalizeTimdexRecord.new(record_with_coverage_date, 'test').normalize
    assert_equal '1995', normalized['year']
  end

  test 'normalizes format from content type' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'Dataset ; Geospatial data', normalized['format']
  end

  test 'handles missing format' do
    record_without_format = minimal_record.dup
    record_without_format.delete('contentType')
    normalized = NormalizeTimdexRecord.new(record_without_format, 'test').normalize
    assert_empty normalized['format']
  end

  test 'normalizes links from source link' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_links = [
      {
        'kind' => 'full record',
        'url' => 'https://example.com/source/record/123',
        'text' => 'View full record'
      }
    ]
    assert_equal expected_links, normalized['links']
  end

  test 'handles missing links' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['links']
  end

  test 'normalizes citation' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'Smith, J. & Doe, J. (2023). Sample TIMDEX Record for Testing. Test Repository.',
                 normalized['citation']
  end

  test 'handles missing citation' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['citation']
  end

  test 'normalizes identifier' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'test-record-123', normalized['identifier']
  end

  test 'normalizes summary' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'This is a comprehensive test record with all possible fields populated for testing normalization.',
                 normalized['summary']
  end

  test 'handles missing summary' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['summary']
  end

  test 'extracts publisher from contributors' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'MIT Libraries', normalized['publisher']
  end

  test 'handles missing publisher' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['publisher']
  end

  test 'normalizes location' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'Cambridge, MA', normalized['location']
  end

  test 'handles missing location' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['location']
  end

  test 'joins multiple locations with semicolon' do
    record_with_multiple_locations = full_record.dup
    record_with_multiple_locations['locations'] = [
      { 'value' => 'Cambridge, MA' },
      { 'value' => 'Boston, MA' },
      { 'value' => 'New York, NY' }
    ]
    normalized = NormalizeTimdexRecord.new(record_with_multiple_locations, 'test').normalize
    assert_equal 'Cambridge, MA; Boston, MA; New York, NY', normalized['location']
  end

  test 'normalizes subjects' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal ['Geographic Information Systems', 'Remote Sensing'], normalized['subjects']
  end

  test 'handles missing subjects' do
    normalized = NormalizeTimdexRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['subjects']
  end

  # Test TIMDEX-specific fields
  test 'includes TIMDEX-specific content_type field' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_content_type = [
      { 'value' => 'Dataset' },
      { 'value' => 'Geospatial data' }
    ]
    assert_equal expected_content_type, normalized['content_type']
  end

  test 'includes TIMDEX-specific dates field' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_dates = [
      { 'kind' => 'Publication date', 'value' => '2023-01-15' },
      { 'kind' => 'Coverage', 'value' => '2020-2023' }
    ]
    assert_equal expected_dates, normalized['dates']
  end

  test 'includes TIMDEX-specific contributors field' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_contributors = [
      { 'kind' => 'Creator', 'value' => 'Smith, Jane' },
      { 'kind' => 'Author', 'value' => 'Doe, John' },
      { 'kind' => 'Publisher', 'value' => 'MIT Libraries' }
    ]
    assert_equal expected_contributors, normalized['contributors']
  end

  test 'includes TIMDEX-specific highlight field' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    expected_highlight = {
      'title' => ['Sample <em>TIMDEX</em> Record'],
      'summary' => ['comprehensive <em>test</em> record']
    }
    assert_equal expected_highlight, normalized['highlight']
  end

  test 'includes TIMDEX-specific source_link field' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize
    assert_equal 'https://example.com/source/record/123', normalized['source_link']
  end

  # Test that Primo-only fields are not included
  test 'does not include Primo-only fields' do
    normalized = NormalizeTimdexRecord.new(full_record, 'test').normalize

    assert_not_includes normalized.keys, 'availability'
    assert_not_includes normalized.keys, 'numbering'
    assert_not_includes normalized.keys, 'chapter_numbering'
    assert_not_includes normalized.keys, 'thumbnail'
    assert_not_includes normalized.keys, 'other_availability'
    assert_not_includes normalized.keys, 'container'
  end
end
