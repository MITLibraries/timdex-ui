require 'test_helper'

class RackAttackBlocklistTest < ActionDispatch::IntegrationTest
  def test_blocked_user_agent_returns_403
    get '/results', params: { q: 'test' }, headers: { 'HTTP_USER_AGENT' => 'Sogou web spider/4.0' }
    assert_equal 403, status
  end

  def test_blocklist_with_partial_user_agent_match
    # 'Sogou web spider' should match 'Sogou web spider/4.0 (compatible; like Gecko)'
    # via include? partial string match
    get '/results', params: { q: 'test' },
                    headers: { 'HTTP_USER_AGENT' => 'Sogou web spider/4.0 (compatible; like Gecko)' }
    assert_equal 403, status
  end

  def test_blocked_user_agent_substring_match
    # Verify that partial matches work
    get '/results', params: { q: 'test' }, headers: { 'HTTP_USER_AGENT' => 'Sogou web spider' }
    assert_equal 403, status
  end
end
