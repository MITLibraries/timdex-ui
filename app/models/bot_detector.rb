class BotDetector
  # Returns true if the request appears to be a bot according to crawler_detect.
  def self.bot?(request)
    ua = request.user_agent.to_s
    detector = CrawlerDetect.new(ua)
    detector.crawler?
  rescue StandardError => e
    Rails.logger.warn("BotDetector: crawler_detect failed for UA '#{ua}': #{e.message}")
    false
  end

  # Returns true when the request appears to be performing crawling behavior that we
  # want to challenge. For our initial approach, treat requests to the search results
  # endpoint as subject to challenge if they're flagged as bots.
  def self.should_challenge?(request, params = {})
    return false unless bot?(request)

    # Basic rule: crawling any results page triggers a challenge. We consider the
    # SearchController `results` action (path `/results`) and other search-related
    # paths to be search result pages. This keeps the rule simple and conservative.
    path = request.path.to_s
    return true if path.start_with?('/search') || path.start_with?('/results') || path.include?('/search')

    false
  end
end
