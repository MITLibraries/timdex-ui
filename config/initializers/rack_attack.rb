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

  ### Throttle Spammy Clients ###

  # If any single client IP is making tons of requests, then they're
  # probably malicious or a poorly-configured scraper. Either way, they
  # don't deserve to hog all of the app server's CPU. Cut them off!
  #
  # Note: If you're serving assets through rack, those requests may be
  # counted by rack-attack and this throttle may be activated too
  # quickly. If so, enable the condition to exclude them from tracking.

  # Throttle all requests by IP (default is 100 requests per 10 minutes)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  throttle('req/ip',
          limit: (ENV.fetch('REQUESTS_PER_PERIOD') { 100 }).to_i,
          period: (ENV.fetch('REQUEST_PERIOD') { 10 }).to_i.minutes) do |req|
    # don't include assets as requests
    req.ip unless req.path.start_with?('/assets')
  end

  # Throttle redirects by IP (default is 5 per 10 minutes)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip/redirects:#{req.ip}"
  throttle('req/ip/redirects',
          limit: (ENV.fetch('REDIRECT_REQUESTS_PER_PERIOD') { 5 }).to_i,
          period: (ENV.fetch('REDIRECT_REQUEST_PERIOD') { 10 }).to_i.minutes) do |req|
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

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  # self.throttled_response = lambda do |env|
  #  [ 503,  # status
  #    {},   # headers
  #    ['']] # body
  # end

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
