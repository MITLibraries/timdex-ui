class ApplicationController < ActionController::Base
  helper Mitlibraries::Theme::Engine.helpers

  # Set active tab based on feature flag and params
  # Also stores the last used tab in a cookie for future searches when passed via params.
  # We set this in a session cookie to persist user preference across searches.
  # Clicking on a different tab will update the cookie.
  def set_active_tab
    # GeoData doesn't use the tab system.
    return if Feature.enabled?(:geodata)

    @active_tab = if params[:tab].present? && valid_tab?(params[:tab])
                    # If params[:tab] is set and valid, use it and set session
                    cookies[:last_tab] = params[:tab]
                  elsif cookies[:last_tab].present? && valid_tab?(cookies[:last_tab])
                    # Otherwise, check for last used tab in session if valid
                    cookies[:last_tab]
                  else
                    # Default behavior when no tab is specified in params or session
                    cookies[:last_tab] = 'all'
                  end
  end

  def primo_tabs
    %w[alma cdi primo]
  end

  def timdex_tabs
    %w[aspace timdex timdex_alma website]
  end

  def all_tabs
    ['all', *primo_tabs, *timdex_tabs]
  end

  private

  def valid_tab?(tab)
    all_tabs.include?(tab)
  end
end
