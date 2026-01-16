class ThirdironController < ApplicationController
  layout false

  def libkey
    return unless ThirdIron.enabled? && expected_params?

    @libkey = Libkey.lookup(type: params[:type], identifier: params[:identifier])
    @doi = params[:type] == 'doi' ? params[:identifier] : nil
    @pmid = params[:type] == 'pmid' ? params[:identifier] : nil
  end

  def browzine
    return unless ThirdIron.enabled? && params[:issn].present?

    @browzine = Browzine.lookup(issn: params[:issn])
  end

  private

  def expected_params?
    params[:type].present? && params[:identifier].present?
  end
end
