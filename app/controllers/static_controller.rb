require 'uri'

class StaticController < ApplicationController
  def style_guide; end

  def about_natural_language_search; end

  def about; end

  def boolpref
    if params[:boolean_type].present?
      cookies[:boolean_type] = params[:boolean_type]
    else
      cookies.delete :boolean_type
    end

    redirect_back_or_to root_path
  end

  def natural_language_search_optin
    optin = params[:natural_language_search_optin]
    if %w[true false].include?(optin)
      nls_cookie_options = if use_domain_cookies?
                             { value: optin, domain: '.libraries.mit.edu', expires: 1.year.from_now }
                           else
                             { value: optin, expires: 1.year.from_now }
                           end
      cookies['STYXKEY_nls_enabled'] = nls_cookie_options
    else
      cookies.delete 'STYXKEY_nls_enabled', domain: '.libraries.mit.edu' if use_domain_cookies?
      cookies.delete 'STYXKEY_nls_enabled' unless use_domain_cookies?
    end

    # Clean up old cookie names no longer in use
    # Note: max date nls_enabled will be needed is 2027-07-01, when all old cookies will have expired.
    cookies.delete :nls_enabled, domain: '.libraries.mit.edu' if use_domain_cookies?
    cookies.delete :nls_enabled unless use_domain_cookies?

    # Redirect to return_to param if it's a safe local path, otherwise root
    return_to = params[:return_to].presence
    safe_return_to = nil
    if return_to
      begin
        parsed = URI.parse(return_to)
        # Only allow local paths with no host or scheme
        if parsed.path&.start_with?('/') && !return_to.start_with?('//') && parsed.host.nil? && parsed.scheme.nil?
          safe_return_to = return_to
        end
      rescue URI::InvalidURIError
        safe_return_to = nil
      end
    end
    redirect_to(safe_return_to || root_path)
  end

  private

  def use_domain_cookies?
    host = request.host.to_s.downcase
    host == 'libraries.mit.edu' || host.end_with?('.libraries.mit.edu')
  end
end
