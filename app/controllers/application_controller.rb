class ApplicationController < ActionController::Base
  helper Mitlibraries::Theme::Engine.helpers

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
