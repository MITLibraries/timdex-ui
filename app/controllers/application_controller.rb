class ApplicationController < ActionController::Base
  helper Mitlibraries::Theme::Engine.helpers

  before_action :set_natural_language_search_optin

  # Set active tab based on params (no persistent cookie). This intentionally
  # avoids storing the user's last-used tab in a cookie per UXWS request.
  def set_active_tab
    # GeoData doesn't use the tab system.
    return if Feature.enabled?(:geodata)

    @active_tab = if params[:tab].present? && valid_tab?(params[:tab])
                    params[:tab]
                  else
                    'all'
                  end
  end

  def primo_tabs
    %w[alma cdi primo]
  end

  def timdex_tabs
    %w[aspace databases dspace geodata timdex timdex_alma website]
  end

  def all_tabs
    ['all', *primo_tabs, *timdex_tabs]
  end

  private

  def valid_tab?(tab)
    all_tabs.include?(tab)
  end

  # Set the natural language search opt-in state for the current request.
  def set_natural_language_search_optin
    @natural_language_search_optin = nls_enabled_value == 'true'
  end

  # Get the natural language search opt-in value with fallback support.
  #
  # Returns the value from the current STYXKEY_nls_enabled cookie, or falls back to
  # the old nls_enabled cookie for backward compatibility during the transition period.
  # Max future date we need this fall back is 2027-07-01, when all old cookies will have expired.
  # All previous cookie names were session cookies, so we no longer support them at all.
  def nls_enabled_value
    cookies['STYXKEY_nls_enabled'] || cookies[:nls_enabled]
  end
end
