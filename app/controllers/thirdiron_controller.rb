require 'uri'

class ThirdironController < ApplicationController
  layout false

  def libkey
    return unless ThirdIron.enabled? && expected_params?

    @libkey = Libkey.lookup(type: params[:type], identifier: params[:identifier])
    @doi = params[:type] == 'doi' ? params[:identifier] : nil
    @pmid = params[:type] == 'pmid' ? params[:identifier] : nil
    @format = params[:format]
  end

  def browzine
    return unless ThirdIron.enabled? && params[:issn].present?

    @browzine = Browzine.lookup(issn: params[:issn])
    @full_record_url = safe_full_record_url(params[:full_record_url])
  end

  private

  def expected_params?
    params[:type].present? && params[:identifier].present?
  end

  def safe_full_record_url(url)
    return nil unless url.is_a?(String)

    url = url.strip
    return nil if url.blank?

    parsed = URI.parse(url)
    return nil unless parsed.is_a?(URI::HTTP)
    return nil if parsed.host.blank?
    return nil if parsed.userinfo.present?

    parsed.to_s
  rescue URI::InvalidURIError, ArgumentError
    nil
  end
end
