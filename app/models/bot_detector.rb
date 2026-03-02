class BotDetector
  # Returns true if the request appears to be a bot according to crawler_detect.
  def self.bot?(request)
    ua = request.user_agent.to_s
    detector = CrawlerDetect.new(ua)
    detector.is_crawler?
  rescue StandardError => e
    Rails.logger.debug("BotDetector: crawler_detect failed for UA '#{ua}': #{e.message}")
    false
  end

  # Returns true when the request appears to be performing crawling behavior that we
  # want to challenge. For our initial approach, treat requests to the search results
  # endpoint as subject to challenge if they're flagged as bots.
  def self.should_challenge?(request)
    return false unless bot?(request)

    # Basic rule: crawling search results or record pages triggers a challenge.
    # /results is the search results page and /record is the full record view.
    # This keeps the rule simple and conservative.
    path = request.path.to_s
    return true if path.start_with?('/results') || path.start_with?('/record')

    false
  end
end
