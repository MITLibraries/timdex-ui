require 'test_helper'

class NormalizePrimoRecordTest < ActiveSupport::TestCase
  # Hopefully we won't need to create new records that often, but if it comes up, you can query the
  # Primo Search API, grab a result, and use the structure in the `pnx` field as a starting point.
  # From there, it's a manual process of filling in the data you need for the test assertions.
  def full_record
    JSON.parse(File.read(Rails.root.join('test/fixtures/primo/full_record.json')))
  end

  def minimal_record
    JSON.parse(File.read(Rails.root.join('test/fixtures/primo/minimal_record.json')))
  end

  test 'normalizes title' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'Testing the Limits of Knowledge', normalized['title']
  end

  test 'handles missing title' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_equal 'unknown title', normalized['title']
  end

  test 'normalizes creators' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    expected_creators = ['Smith, John A.', 'Jones, Mary B.', 'Brown, Robert C.']
    assert_equal expected_creators.sort, normalized['creators'].map { |c| c[:value] }.sort
  end

  test 'handles missing creators' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['creators']
  end

  test 'normalizes source' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'Primo', normalized['source']
  end

  test 'normalizes year' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal '2023', normalized['year']
  end

  test 'handles missing year' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['year']
  end

  test 'normalizes format' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'Book', normalized['format']
  end

  test 'handles missing format' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['format']
  end

  test 'normalizes links' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize

    # First link should be the record link
    assert_equal 'full record', normalized['links'].first['kind']

    # Second link should be the Alma openurl
    assert_equal 'openurl', normalized['links'].second['kind']
  end

  test 'handles missing links' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['links']
  end

  test 'normalizes citation' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'volume 2 issue 3', normalized['citation']
  end

  test 'handles missing citation' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['citation']
  end

  test 'normalizes container title' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'Journal of Testing', normalized['container']
  end

  test 'handles missing container title' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['container']
  end

  test 'normalizes identifier' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'MIT01000000001', normalized['identifier']
  end

  test 'normalizes summary' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'A comprehensive study of testing methodologies', normalized['summary']
  end

  test 'handles missing summary' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['summary']
  end

  test 'handles missing identifier' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['identifier']
  end

  test 'normalizes numbering' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'volume 2 issue 3', normalized['numbering']
  end

  test 'handles missing numbering' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['numbering']
  end

  test 'normalizes chapter numbering' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal '2023, pp. 123-145', normalized['chapter_numbering']
  end

  test 'handles missing chapter numbering' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['chapter_numbering']
  end

  test 'includes FRBRized dedup record link in links when available' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    record_link = normalized['links'].find { |link| link['kind'] == 'full record' }
    assert_not_nil record_link

    # For FRBRized records, should use dedup URL format
    assert_match %r{/discovery/search\?}, record_link['url']
    assert_match 'frbrgroupid', record_link['url']
  end

  test 'generates thumbnail from ISBN' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    expected_url = 'https://syndetics.com/index.php?client=primo&isbn=9781234567890/sc.jpg'
    assert_equal expected_url, normalized['thumbnail']
  end

  test 'handles missing ISBN for thumbnail' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['thumbnail']
  end

  test 'extracts publisher information' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'MIT Press', normalized['publisher']
  end

  test 'handles missing publisher' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['publisher']
  end

  test 'returns best location with call number' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    expected_location = ['Hayden Library Stacks', 'QA76.73.R83 2023']
    assert_equal expected_location, normalized['location']
  end

  test 'handles missing location' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['location']
  end

  test 'extracts subjects' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    expected_subjects = ['Computer Science', 'Software Testing']
    assert_equal expected_subjects, normalized['subjects']
  end

  test 'handles missing subjects' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_empty normalized['subjects']
  end

  test 'returns availability status' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert_equal 'available', normalized['availability']
  end

  test 'handles missing availability' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['availability']
  end

  test 'detects other availability when multiple holdings exist' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    assert normalized['other_availability']
  end

  test 'handles missing other availability' do
    normalized = NormalizePrimoRecord.new(minimal_record, 'test').normalize
    assert_nil normalized['other_availability']
  end

  test 'uses dedup URL as full record link for frbrized records' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    full_record_link = normalized['links'].find { |link| link['kind'] == 'full record' }
    assert_not_nil full_record_link

    expected_base = 'https://mit.primo.exlibrisgroup.com/discovery/search?'
    assert_match expected_base, full_record_link['url']
    assert_match 'frbrgroupid%2Cinclude%2C12345', full_record_link['url']
  end

  test 'falls back to record link when no dedup URL available' do
    # Remove FRBR data from record
    record_without_frbr = full_record.deep_dup
    record_without_frbr['pnx']['facets']['frbrtype'] = ['3']

    normalized = NormalizePrimoRecord.new(record_without_frbr, 'test').normalize
    full_record_link = normalized['links'].find { |link| link['kind'] == 'full record' }
    assert_not_nil full_record_link
    assert_match %r{/discovery/fulldisplay\?}, full_record_link['url']
  end

  test 'includes expected link types when available' do
    normalized = NormalizePrimoRecord.new(full_record, 'test query').normalize
    link_kinds = normalized['links'].map { |link| link['kind'] }

    assert_includes link_kinds, 'full record'
    assert_includes link_kinds, 'openurl'
    assert_equal 2, normalized['links'].length # Only full record and openurl
  end

  # Additional coverage tests for existing methods
  test 'handles multiple creators with semicolons' do
    record = full_record.deep_dup
    record['pnx']['display']['creator'] = ['Smith, John A.; Doe, Jane B.']
    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    creators = normalized['creators'].map { |c| c[:value] }
    assert_includes creators, 'Smith, John A.'
    assert_includes creators, 'Doe, Jane B.'
  end

  test 'sanitizes authors by removing $$ codes' do
    record = full_record.deep_dup
    record['pnx']['display']['creator'] = ['Smith, John A.$$QAuthor']
    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal 'Smith, John A.', normalized['creators'].first[:value]
  end

  test 'constructs author search links' do
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    creator_link = normalized['creators'].first[:link]
    assert_match 'discovery/search?query=creator,exact,', creator_link
    assert_match 'Smith%2C%20John%20A.', creator_link
  end

  test 'normalizes different format types' do
    test_cases = [
      ['BKSE', 'eBook'],
      ['reference_entry', 'Reference Entry'],
      ['Book_chapter', 'Book Chapter'],
      ['article', 'Article']
    ]

    test_cases.each do |input, expected|
      record = full_record.deep_dup
      record['pnx']['display']['type'] = [input]
      normalized = NormalizePrimoRecord.new(record, 'test').normalize
      assert_equal expected, normalized['format']
    end
  end

  test 'uses search creationdate when display is missing' do
    record = minimal_record.deep_dup
    record['pnx']['search'] = { 'creationdate' => ['2022'] }

    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal '2022', normalized['year']
  end

  test 'handles different citation formats' do
    # Test with just volume
    record = full_record.deep_dup
    record['pnx']['addata'] = { 'volume' => ['5'] }
    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal 'volume 5', normalized['citation']

    # Test with date and pages
    record['pnx']['addata'] = { 'date' => ['2023'], 'pages' => ['10-20'] }
    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal '2023, pp. 10-20', normalized['citation']
  end

  test 'prefers jtitle over btitle for container' do
    record = full_record.deep_dup
    record['pnx']['addata']['jtitle'] = ['Journal Title']
    record['pnx']['addata']['btitle'] = ['Book Title']

    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal 'Journal Title', normalized['container']
  end

  test 'uses btitle when jtitle is not present for container' do
    record = full_record.deep_dup
    record['pnx']['addata'].delete('jtitle') # Remove jtitle
    record['pnx']['addata']['btitle'] = ['Book Title Only']

    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    assert_equal 'Book Title Only', normalized['container']
  end

  test 'handles openurl server validation' do
    # Test with matching server
    normalized = NormalizePrimoRecord.new(full_record, 'test').normalize
    openurl_link = normalized['links'].find { |link| link['kind'] == 'openurl' }
    assert_not_nil openurl_link

    # Test with mismatched server. Should log warning but still return URL
    record = full_record.deep_dup
    record['delivery']['almaOpenurl'] = 'https://different.server.com/openurl?param=value'
    normalized = NormalizePrimoRecord.new(record, 'test').normalize
    openurl_link = normalized['links'].find { |link| link['kind'] == 'openurl' }
    assert_not_nil openurl_link
  end
end
