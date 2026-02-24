require 'test_helper'
require 'ostruct'

class BotDetectorTest < ActiveSupport::TestCase
  test 'bot? detects bots when crawler_detect returns true' do
    request = mock(user_agent: 'Googlebot/2.1')
    
    # Mock CrawlerDetect to return a detector that reports a bot
    mock_detector = mock(crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    assert BotDetector.bot?(request)
  end

  test 'bot? allows non-bots when crawler_detect returns false' do
    request = mock(user_agent: 'Mozilla/5.0 (X11; Linux x86_64)')
    
    mock_detector = mock(crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    refute BotDetector.bot?(request)
  end

  test 'bot? handles nil user agent gracefully' do
    request = mock(user_agent: nil)
    
    mock_detector = mock(crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    refute BotDetector.bot?(request)
  end

  test 'bot? logs and returns false on detector failure' do
    request = mock(user_agent: 'Test UA')
    
    # Mock crawler_detect to raise an error
    CrawlerDetect.stubs(:new).raises(StandardError.new('Detector failure'))
    
    Rails.logger.expects(:warn).with(includes('BotDetector: crawler_detect failed'))
    
    refute BotDetector.bot?(request)
  end

  test 'should_challenge? returns false for non-bots' do
    request = OpenStruct.new(user_agent: 'Mozilla/5.0 (X11; Linux)', path: '/search')
    
    mock_detector = mock(crawler?: false)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    refute BotDetector.should_challenge?(request)
  end

  test 'should_challenge? returns false for bots not on search paths' do
    bot_ua = 'Googlebot/2.1'
    request = OpenStruct.new(user_agent: bot_ua, path: '/static/style-guide')
    
    mock_detector = mock(crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    refute BotDetector.should_challenge?(request)
  end

  test 'should_challenge? returns true for bots on /search paths' do
    bot_ua = 'Googlebot/2.1'
    request = OpenStruct.new(user_agent: bot_ua, path: '/search')
    
    mock_detector = mock(crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    assert BotDetector.should_challenge?(request)
  end

  test 'should_challenge? returns true for bots on results endpoint' do
    bot_ua = 'Mozilla/5.0 (compatible; bingbot/2.0)'
    request = OpenStruct.new(user_agent: bot_ua, path: '/results?q=test')
    
    mock_detector = mock(crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    assert BotDetector.should_challenge?(request)
  end

  test 'should_challenge? handles nil path gracefully' do
    bot_ua = 'Googlebot/2.1'
    request = OpenStruct.new(user_agent: bot_ua, path: nil)
    
    mock_detector = mock(crawler?: true)
    CrawlerDetect.stubs(:new).returns(mock_detector)
    
    refute BotDetector.should_challenge?(request)
  end
end
