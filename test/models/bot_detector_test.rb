require 'test_helper'
require 'ostruct'

class BotDetectorTest < ActiveSupport::TestCase
  # Helper method to instantiate request objects.
  def request(user_agent, path)
    Struct.new(:user_agent, :path).new(user_agent, path)
  end

  test 'bot? detects bots when crawler_detect returns true' do
    request = mock(user_agent: 'Googlebot/2.1')

    # Mock CrawlerDetect to return a detector that reports a bot
    mock_detector = mock(is_crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    assert BotDetector.bot?(request)
  end

  test 'bot? allows non-bots when crawler_detect returns false' do
    request = mock(user_agent: 'Mozilla/5.0 (X11; Linux x86_64)')

    mock_detector = mock(is_crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.bot?(request)
  end

  test 'bot? handles nil user agent gracefully' do
    request = mock(user_agent: nil)

    mock_detector = mock(is_crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.bot?(request)
  end

  test 'bot? logs and returns false on detector failure' do
    request = mock(user_agent: 'Test UA')

    # Mock crawler_detect to raise an error
    CrawlerDetect.stubs(:new).raises(StandardError.new('Detector failure'))

    Rails.logger.expects(:debug).with(includes('BotDetector: crawler_detect failed'))

    refute BotDetector.bot?(request)
  end

  test 'should_challenge? returns false for non-bots' do
    req = request('Mozilla/5.0 (X11; Linux)', '/search')

    mock_detector = mock(is_crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.should_challenge?(req)
  end

  test 'should_challenge? returns false for bots not on search paths' do
    bot_ua = 'Googlebot/2.1'
    req = request(bot_ua, '/static/style-guide')

    mock_detector = mock(is_crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.should_challenge?(req)
  end

  test 'should_challenge? returns false for bots on /search paths' do
    bot_ua = 'Googlebot/2.1'
    req = request(bot_ua, '/search')

    mock_detector = mock(is_crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.should_challenge?(req)
  end

  test 'should_challenge? returns true for bots on results endpoint' do
    bot_ua = 'Mozilla/5.0 (compatible; bingbot/2.0)'
    req = request(bot_ua, '/results?q=test')

    mock_detector = mock(is_crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    assert BotDetector.should_challenge?(req)
  end

  test 'should_challenge? handles nil path gracefully' do
    bot_ua = 'Googlebot/2.1'
    req = request(bot_ua, path: nil)

    mock_detector = mock(is_crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)

    refute BotDetector.should_challenge?(req)
  end
end
