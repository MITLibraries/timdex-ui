require 'uri'

class StaticController < ApplicationController
  def style_guide; end

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
      cookies[:natural_language_search_optin] = optin
    else
      cookies.delete :natural_language_search_optin
    end

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
end
