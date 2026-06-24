class TurnstileController < ApplicationController
  before_action :validate_cloudflare_turnstile, only: :verify

  rescue_from RailsCloudflareTurnstile::Forbidden, with: :handle_forbidden

  def show
    @return_to = params[:return_to].presence || root_path
  end

  # Marks the user as having passed Turnstile verification by setting both a session flag
  # and a plain cookie with grace period.
  #
  # Two different storage mechanisms are used for different purposes:
  #
  # 1. session[:passed_turnstile] = true
  #    - Server-side session state (for view/controller logic compatibility)
  #    - Available to Rails controllers and views
  #
  # 2. cookies[:turnstile_verified_at] (new, primary)
  #    - Plain cookie with expiration timestamp (Unix integer)
  #    - Checked by Rack::Attack middleware *before* request reaches Rails
  #    - Middleware layer reads raw cookie values; signed/encrypted cookies are unreadable
  #    - Survives Redis eviction during attacks (stored on client, not in server cache)
  #    - Enables grace period: Rack Attack skips throttling if cookie timestamp is valid
  #    - Timestamp not sensitive (expiration time is public info); anyone could see it anyway
  #
  # Why both? Rack Attack is middleware that runs before Rails session initialization.
  # Without the plain cookie readable by middleware, every post-Turnstile request would still
  # hit throttles and be challenged again, creating an infinite loop. The cookie signals to
  # the middleware layer: "This IP recently verified; skip throttling until [timestamp]".
  def verify
    session[:passed_turnstile] = true

    # Set a plain cookie to skip Rack Attack throttling for this IP.
    # The cookie contains an expiration timestamp that Rack::Attack middleware can read.
    # Duration is controlled by TURNSTILE_GRACE_PERIOD (minutes; default 15).
    # Survives Redis eviction during attacks (stored on client, not server cache).
    grace_period_minutes = ENV.fetch('TURNSTILE_GRACE_PERIOD', 15).to_i
    expiration_time = Time.current + grace_period_minutes.minutes

    cookies[:turnstile_verified_at] = {
      value: expiration_time.to_i,
      expires: expiration_time,
      httponly: true,
      secure: Rails.env.production?
    }

    redirect_to safe_return_path
  end

  private

  # Handles Turnstile rejecting token submission due to invalid token, network issue, etc.
  def handle_forbidden
    flash.now[:error] = "We couldn't complete the verification. Please try again."
    render :show, status: :unprocessable_entity
  end

  # Returns a safe path to redirect to after Turnstile verification. Valid paths should begin with
  # a single slash. Falls back to root_path if the provided path is invalid.
  def safe_return_path
    return_to = params[:return_to].to_s
    return root_path if return_to.blank?
    return root_path if return_to.start_with?('//')
    return return_to if return_to.start_with?('/')

    root_path
  end
end
