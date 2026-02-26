class TurnstileController < ApplicationController
  before_action :ensure_bot_detection_enabled
  before_action :validate_cloudflare_turnstile, only: :verify

  rescue_from RailsCloudflareTurnstile::Forbidden, with: :handle_forbidden

  def show
    @return_to = params[:return_to].presence || root_path
  end

  def verify
    session[:passed_turnstile] = true
    redirect_to safe_return_path
  end

  private

  def ensure_bot_detection_enabled
    head :not_found unless Feature.enabled?(:bot_detection)
  end

  def handle_forbidden
    flash.now[:error] = 'Turnstile validation failed. Please try again.'
    render :show, status: :unprocessable_entity
  end

  def safe_return_path
    return_to = params[:return_to].to_s
    return root_path if return_to.blank?
    return root_path if return_to.start_with?('//')
    return return_to if return_to.start_with?('/')

    root_path
  end
end
