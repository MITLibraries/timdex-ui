class ApplicationController < ActionController::Base
  helper Mitlibraries::Theme::Engine.helpers

  # Set active tab based on feature flag and params
  # Also stores the last used tab in a cookie for future searches when passed via params.
  # We set this in a session cookie to persist user preference across searches.
  # Clicking on a different tab will update the cookie.
  def set_active_tab
    @active_tab = if Feature.enabled?(:geodata)
                    # Determine which tab to load - default to primo unless gdt is enabled
                    'geodata'
                  elsif params[:tab].present?
                    # If params[:tab] is set, use it and set session
                    cookies[:last_tab] = params[:tab]
                  elsif cookies[:last_tab].present?
                    # Otherwise, check for last used tab in session
                    cookies[:last_tab]
                  else
                    # Default behavior when no tab is specified in params or session
                    cookies[:last_tab] = 'primo'
                  end
  end
end
