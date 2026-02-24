class TurnstileController < ApplicationController
  # Rails CSRF protection stays enabled here. The Turnstile challenge only adds an
  # additional bot validation layer rather than replacing Rails' forgery defenses.

  # Render a page with the Cloudflare Turnstile widget. Expects `TURNSTILE_SITEKEY`
  # to be present in the environment. `return_to` is preserved so we can redirect after success.
  def new
    @sitekey = ENV.fetch('TURNSTILE_SITEKEY', nil)
    @return_to = params[:return_to] || root_path
  end

  # Verify Turnstile token posted by the widget. Expects param `cf-turnstile-response`.
  def verify
    token = params['cf-turnstile-response']
    return_to = params[:return_to].presence || root_path

    if token.blank?
      flash[:error] = 'Turnstile validation failed. Please try again.'
      redirect_to turnstile_path(return_to: return_to)
      return
    end

    secret = ENV.fetch('TURNSTILE_SECRET', nil)
    verification = verify_turnstile_token(secret, token)

    if verification && verification['success']
      session[:passed_turnstile] = true
      redirect_to return_to
    else
      flash[:error] = 'Turnstile verification failed. Please try again.'
      redirect_to turnstile_path(return_to: return_to)
    end
  end

  private

  def verify_turnstile_token(secret, token)
    return nil if secret.blank?

    begin
      response = HTTP.post('https://challenges.cloudflare.com/turnstile/v0/siteverify', form: {
                           secret: secret,
                           response: token,
                         })
      JSON.parse(response.to_s)
    rescue StandardError => e
      Rails.logger.error "Turnstile verification error: #{e.message}"
      nil
    end
  end
end
