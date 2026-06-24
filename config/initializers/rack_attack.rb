class Rack::Attack

  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blocklisting and
  # safelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Safelist MIT IP addresses
  # http://kb.mit.edu/confluence/x/F4DCAg
  # Main IP range (includes campus, NAT pool, and VPNs)
  # This also affects bot_challenge_page logic which uses rack_attack under the hood
  Rack::Attack.safelist_ip("18.0.0.0/11")

  ### Blocklist Suspicious User Agents ###

  # Hard-block requests with user agents commonly associated with botnets or spoofed crawlers.
  # These are immediately rejected with a 403 Forbidden response (much cheaper than throttling).
  #
  # Configure via BLOCKED_USER_AGENTS env var (comma-separated list).
  # Example: "Sogou web spider,BadBot/2.0"
  #
  # Default includes "Sogou web spider" which was responsible for 76.94k attack requests
  # originating from non-Chinese IPs with spoofed user agents.
  blocked_agents = ENV.fetch('BLOCKED_USER_AGENTS', 'Sogou web spider').split(',').map(&:strip)

  Rack::Attack.blocklist('user_agent/blocked') do |req|
    blocked_agents.any? { |agent| req.user_agent&.include?(agent) }
  end

  ### Throttle Spammy Clients ###

  # If any single client IP is making tons of requests, then they're
  # probably malicious or a poorly-configured scraper. Either way, they
  # don't deserve to hog all of the app server's CPU. Cut them off!
  #
  # Note: If you're serving assets through rack, those requests may be
  # counted by rack-attack and this throttle may be activated too
  # quickly. If so, enable the condition to exclude them from tracking.

   # Global rate limit for /results and /record endpoints (excluding any Rack::Attack safelisted IPs)
   # to protect against distributed volume attacks. Per-IP throttling can be bypassed by rotating
   # through many IPs; this shared counter caps total throughput for all non-safelisted traffic.
  #
  # However, after a user passes Turnstile verification, we skip throttling for the grace period
  # (default 15 minutes) to avoid repeated challenges during normal usage.
  # Grace period is verified via an encrypted, tamper-proof cookie set by the Turnstile controller.
  #
  # Default: 30 requests per second across all non-safelisted IPs
  throttle('results/global',
          limit: (ENV.fetch('RESULTS_GLOBAL_LIMIT_PER_SEC', 30)).to_i,
          period: 1.second) do |req|
    # Only apply to /results and /record endpoints
    next nil unless req.path.start_with?('/results') || req.path.start_with?('/record')

    # Skip throttling if this IP recently passed Turnstile verification.
    # Grace period is stored in a plain cookie that survives Redis eviction.
    cookie_value = req.cookies['turnstile_verified_at']
    if cookie_value.present?
      expiration_timestamp = cookie_value.to_i
      next nil if expiration_timestamp > Time.current.to_i
    end

    # Use a constant key so this is a true global limit, not per-IP
    'results'
  end

  # Throttle /results and /record requests more aggressively (default is 10 requests per minute)
  # /results and /record endpoints are expensive and are common targets for botnet
  # attacks using distributed IPs. This throttle is much stricter than the general
  # throttle to defend against distributed bot attacks that stay under per-IP limits
  # by rotating through many IPs.
  #
  # However, after a user passes Turnstile verification, we skip throttling for the grace period
  # (default 15 minutes) to avoid repeated challenges during normal usage.
  # Grace period is verified via an encrypted, tamper-proof cookie set by the Turnstile controller.
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip/results:#{req.ip}"
  throttle('req/ip/results',
          limit: (ENV.fetch('RESULTS_THROTTLE_LIMIT', 10)).to_i,
          period: (ENV.fetch('RESULTS_THROTTLE_PERIOD', 1)).to_i.minutes) do |req|
    # Only apply to /results and /record endpoints
    next nil unless req.path.start_with?('/results') || req.path.start_with?('/record')

    # Skip throttling if this IP recently passed Turnstile verification.
    # Grace period is stored in a plain cookie (not encrypted) that survives Redis eviction.
    cookie_value = req.cookies['turnstile_verified_at']
    if cookie_value.present?
      expiration_timestamp = cookie_value.to_i
      next nil if expiration_timestamp > Time.current.to_i
    end

    req.ip
  end

  # Throttle all requests by IP (default is 100 requests per 10 minutes)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  throttle('req/ip',
          limit: (ENV.fetch('REQUESTS_PER_PERIOD', 100)).to_i,
          period: (ENV.fetch('REQUEST_PERIOD', 10)).to_i.minutes) do |req|
    # don't include assets as requests
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle redirects by IP (default is 5 per 10 minutes)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip/redirects:#{req.ip}"
  throttle('req/ip/redirects',
          limit: (ENV.fetch('REDIRECT_REQUESTS_PER_PERIOD', 5)).to_i,
          period: (ENV.fetch('REDIRECT_REQUEST_PERIOD', 10)).to_i.minutes) do |req|
    req.ip if req.query_string.start_with?('geoweb-redirect')
  end

  ### Prevent Brute-Force Login Attacks ###

  # The most common brute-force login attack is a brute-force password
  # attack where an attacker simply tries a large number of emails and
  # passwords to see if any credentials match.
  #
  # Another common method of attack is to use a swarm of computers with
  # different IPs to try brute-forcing a password for a specific account.

  # Throttle POST requests to /login by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  # throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
  #   if req.path == '/login' && req.post?
  #     req.ip
  #   end
  # end

  # Throttle POST requests to /login by email param
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{req.email}"
  #
  # Note: This creates a problem where a malicious user could intentionally
  # throttle logins for another user and force their login requests to be
  # denied, but that's not very common and shouldn't happen to you. (Knock
  # on wood!)
  # throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  #   if req.path == '/login' && req.post?
  #     # return the email if present, nil otherwise
  #     req.params['email'].presence
  #   end
  # end

  ### Custom Throttle Response ###

  # Redirect /results and /record throttles to Turnstile challenge instead of 429.
  # This allows real users to solve a CAPTCHA and continue, rather than getting
  # hard-blocked. This is more user-friendly for tuning since we can't perfectly
  # distinguish bots from heavy legitimate usage.
  #
  # IMPORTANT: Only redirect if the matched throttle is one that has a grace period cache check
  # (results/global or req/ip/results). Other throttles (req/ip, etc.) don't have grace period
  # exemptions, so redirecting would create an infinite loop.
  #
  # For throttles without grace period support, return 429 instead.
  self.throttled_response = lambda do |env|
    request = Rack::Request.new(env)
    matched_throttle = env['rack.attack.matched']

    # Only redirect to Turnstile for /results and /record if it's a throttle with grace period support
    if (request.path.start_with?('/results') || request.path.start_with?('/record')) &&
       (matched_throttle == 'results/global' || matched_throttle == 'req/ip/results')
      # Redirect to Turnstile challenge
      return_to = "#{request.path_info}?#{request.query_string}".gsub(/\?$/, '')
      [ 302,
        { 'Location' => "/turnstile?return_to=#{ERB::Util.url_encode(return_to)}" },
        [''] ]
    else
      # Default 429 for other throttled paths or throttles without grace period support
      [ 429,
        { 'Content-Type' => 'text/plain' },
        ['Too Many Requests'] ]
    end
  end

  # Block suspicious requests for '/etc/password' or wordpress specific paths.
  # After 3 blocked requests in 10 minutes, block all requests from that IP for 5 minutes.
  # Note: these will not show up in the throttle logs as they are blocks and not throttles
  Rack::Attack.blocklist('fail2ban pentesters') do |req|
    # `filter` returns truthy value if request fails, or if it's from a previously banned IP
    # so the request is blocked
    Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 5.minutes) do
      # The count for the IP is incremented if the return value is truthy
      CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
      req.path.include?('/etc/passwd') ||
      req.path.include?('wp-admin') ||
      req.path.include?('wp-login')
    end
  end

  # Log when throttles are triggered
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
    @@rack_logger ||= ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
    @@rack_logger.info{[
      "[#{payload[:request].env['rack.attack.match_type']}]",
      "[#{payload[:request].env['rack.attack.matched']}]",
      "[#{payload[:request].env['rack.attack.match_discriminator']}]",
      "[#{payload[:request].env['rack.attack.throttle_data']}]",
      ].join(' ') }
  end
end
