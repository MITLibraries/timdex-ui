Rails.application.config.to_prepare do

  BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  # Some testing keys are also available: https://developers.cloudflare.com/turnstile/troubleshooting/testing/
  #
  # Always pass testing sitekey: "1x00000000000000000000AA"
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_sitekey = ENV.fetch('CLOUDFLARE_SITE_KEY', "NOT SET")
  # Always pass testing secret_key: "1x0000000000000000000000000000000AA"
  BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key = ENV.fetch('CLOUDFLARE_SECRET_KEY', "NOT SET")

  BotChallengePage::BotChallengePageController.bot_challenge_config.redirect_for_challenge = false

  # What paths do you want to protect?
  #
  # You can use path prefixes: "/catalog" or even "/"
  #
  # Or hashes with controller and/or action:
  #
  #   { controller: "catalog" }
  #   { controller: "catalog", action: "index" }
  #
  # Note that we can only protect GET paths, and also think about making sure you DON'T protect
  # any path your front-end needs JS `fetch` access to, as this would block it (at least
  # without custom front-end code we haven't really explored)

  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limited_locations = ['/results', '/record']

  # allow rate_limit_count requests in rate_limit_period, before issuing challenge
  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limit_period = ENV.fetch('CLOUDFLARE_REQUEST_PERIOD_IN_HOURS', 12).to_i.hour
  BotChallengePage::BotChallengePageController.bot_challenge_config.rate_limit_count = ENV.fetch('CLOUDFLARE_REQUESTS_PER_PERIOD', 10).to_i

  # How long will a challenge success exempt a session from further challenges?
  # BotChallengePage::BotChallengePageController.bot_challenge_config.session_passed_good_for = 36.hours

  # Exempt some requests from bot challenge protection
  # BotChallengePage::BotChallengePageController.bot_challenge_config.allow_exempt = ->(controller) {
  #   # controller.params
  #   # controller.request
  #   # controller.session

  #   # Here's a way to identify browser `fetch` API requests; note
  #   # it can be faked by an "attacker"
  #   controller.request.headers["sec-fetch-dest"] == "empty"
  # }

  # More configuration is available

  BotChallengePage::BotChallengePageController.rack_attack_init
end
