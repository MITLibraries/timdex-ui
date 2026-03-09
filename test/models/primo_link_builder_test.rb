# Test NDE link generation
require 'test_helper'

class PrimoLinkBuilderTest < ActiveSupport::TestCase
  test 'search_link generates Primo discovery URL by default' do
    link = PrimoLinkBuilder.new(query_term: 'machine learning').search_link

    assert_includes link, '/discovery/search?'
    assert_includes link, 'query=any%2Ccontains%2Cmachine+learning'
    assert_includes link, 'vid=01MIT_INST%3AMIT'
  end

  test 'search_link generates Primo NDE URL when feature flag us enabled' do
    ClimateControl.modify(FEATURE_PRIMO_NDE_LINKS: 'true') do
      link = PrimoLinkBuilder.new(query_term: 'machine learning').search_link

      assert_includes link, '/nde/search?'
      assert_includes link, 'query=machine+learning'
      assert_includes link, 'vid=01MIT_INST%3ANDE'
      assert_not_includes link, 'any%2Ccontains'
    end
  end

  test 'full_record_link generates discovery URL by default' do
    link = PrimoLinkBuilder.new(record_id: 'alma990003098710106761', context: 'L').full_record_link

    assert_includes link, '/discovery/fulldisplay?'
    assert_includes link, 'docid=alma990003098710106761'
    assert_includes link, 'vid=01MIT_INST%3AMIT'
    assert_includes link, 'context=L'
  end

  test 'full_record_link generates NDE URL when feature flag enabled' do
    ClimateControl.modify(FEATURE_PRIMO_NDE_LINKS: 'true') do
      link = PrimoLinkBuilder.new(record_id: 'alma990003098710106761', context: 'L').full_record_link

      assert_includes link, '/nde/fulldisplay?'
      assert_includes link, 'docid=alma990003098710106761'
      assert_includes link, 'vid=01MIT_INST%3ANDE'
      assert_includes link, 'context=L'
    end
  end

  test 'search_link returns nil when query_term is nil' do
    link = PrimoLinkBuilder.new(query_term: nil).search_link

    assert_nil link
  end

  test 'full_record_link returns nil when record_id is missing' do
    link = PrimoLinkBuilder.new(context: 'foo').full_record_link

    assert_nil link
  end

  test 'full_record_link returns nil when context is missing' do
    link = PrimoLinkBuilder.new(record_id: 'alma123').full_record_link

    assert_nil link
  end

  test 'search_link generates complete URL for discovery' do
    builder = PrimoLinkBuilder.new(query_term: 'database security')
    link = builder.search_link

    expected = 'https://mit.primo.exlibrisgroup.com/discovery/search?query=any%2Ccontains%2Cdatabase+security&tab=all&search_scope=cdi&vid=01MIT_INST%3AMIT'
    assert_equal expected, link
  end

  test 'search_link generates complete URL for NDE' do
    ClimateControl.modify(FEATURE_PRIMO_NDE_LINKS: 'true') do
      builder = PrimoLinkBuilder.new(query_term: 'machine learning')
      link = builder.search_link

      expected = 'https://mit.primo.exlibrisgroup.com/nde/search?query=machine+learning&tab=all&search_scope=cdi&vid=01MIT_INST%3ANDE'
      assert_equal expected, link
    end
  end

  test 'full_record_link generates complete URL for discovery' do
    builder = PrimoLinkBuilder.new(record_id: 'alma990003098710106761', context: 'L')
    link = builder.full_record_link

    assert link.start_with?('https://mit.primo.exlibrisgroup.com/discovery/fulldisplay?')
    assert_includes link, 'docid=alma990003098710106761'
    assert_includes link, 'context=L'
    assert_includes link, 'vid=01MIT_INST%3AMIT'
    assert_includes link, 'search_scope=cdi'
    assert_includes link, 'lang=en'
  end

  test 'full_record_link generates complete URL for NDE' do
    ClimateControl.modify(FEATURE_PRIMO_NDE_LINKS: 'true') do
      builder = PrimoLinkBuilder.new(record_id: 'alma990003098710106761', context: 'P')
      link = builder.full_record_link

      assert link.start_with?('https://mit.primo.exlibrisgroup.com/nde/fulldisplay?')
      assert_includes link, 'docid=alma990003098710106761'
      assert_includes link, 'context=P'
      assert_includes link, 'vid=01MIT_INST%3ANDE'
      assert_includes link, 'search_scope=cdi'
      assert_includes link, 'lang=en'
    end
  end
end
