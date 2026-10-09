require 'test_helper'

class FulfillmentPolicyTest < ActiveSupport::TestCase
  test 'primo_actions includes full record action when record links enabled' do
    result = {
      links: [
        { 'kind' => 'full record', 'url' => 'https://example.com/full-record' },
        { 'kind' => 'Get PDF', 'url' => 'https://example.com/pdf' },
        { 'kind' => 'Full-text options', 'url' => 'https://example.com/fulltext' }
      ]
    }

    policy = FulfillmentPolicy.new(result: result)
    actions = policy.primo_actions(record_link_enabled: true)

    assert_equal 3, actions.length
    assert_equal 'View full record', actions[0][:label]
    assert_equal 'view_full_record', actions[0][:data][:action_type]
    assert_equal 'Get PDF', actions[1][:label]
    assert_equal 'primo_link', actions[1][:data][:action_type]
    assert_equal 'Full-text options', actions[2][:label]
    assert_equal 'full_text_options', actions[2][:data][:action_type]
  end

  test 'primo_actions excludes full record action when record links disabled' do
    result = {
      links: [
        { 'kind' => 'full record', 'url' => 'https://example.com/full-record' },
        { 'kind' => 'Read online', 'url' => 'https://example.com/read' }
      ]
    }

    policy = FulfillmentPolicy.new(result: result)
    actions = policy.primo_actions(record_link_enabled: false)

    assert_equal 1, actions.length
    assert_equal 'Read online', actions[0][:label]
    assert_equal 'primo_link', actions[0][:data][:action_type]
  end

  test 'browzine_full_record_url returns full record url when no full-text options exists' do
    result = {
      links: [
        { 'kind' => 'full record', 'url' => 'https://example.com/full-record' },
        { 'kind' => 'Read online', 'url' => 'https://example.com/read' }
      ]
    }

    policy = FulfillmentPolicy.new(result: result)

    assert_equal 'https://example.com/full-record', policy.browzine_full_record_url
    assert_not policy.send(:existing_full_text_options?)
  end

  test 'browzine_full_record_url returns nil when full-text options already exists' do
    result = {
      links: [
        { 'kind' => 'full record', 'url' => 'https://example.com/full-record' },
        { 'kind' => 'Full-text options', 'url' => 'https://example.com/fulltext' }
      ]
    }

    policy = FulfillmentPolicy.new(result: result)

    assert_nil policy.browzine_full_record_url
    assert policy.send(:existing_full_text_options?)
  end

  test 'browzine_full_record_url returns nil when full record link is missing' do
    result = {
      links: [
        { 'kind' => 'Read online', 'url' => 'https://example.com/read' }
      ]
    }

    policy = FulfillmentPolicy.new(result: result)

    assert_nil policy.browzine_full_record_url
  end
end
