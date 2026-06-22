class TurnstileController < ApplicationController
  before_action :validate_cloudflare_turnstile, only: :verify

  rescue_from RailsCloudflareTurnstile::Forbidden, with: :handle_forbidden

  def show
    @return_to = params[:return_to].presence || root_path
  end

  def verify
    session[:passed_turnstile] = true

    # Whitelist this IP from the Rack::Attack `results/global` and `req/ip/results` throttles after passing Turnstile.
    # Duration is controlled by TURNSTILE_GRACE_PERIOD (minutes; default 15) to avoid repeated challenges.
    cache_key = "turnstile_verified:#{request.ip}"
    grace_period = ENV.fetch('TURNSTILE_GRACE_PERIOD') { 15 }.to_i.minutes
    Rails.cache.write(cache_key, true, expires_in: grace_period)

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
