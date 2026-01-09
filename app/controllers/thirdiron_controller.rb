class ThirdironController < ApplicationController
  layout false

  def libkey
    return unless Libkey.enabled? && expected_params?

    @libkey = Libkey.lookup(type: params[:type], identifier: params[:identifier])
  end

  def browzine
    return unless Libkey.enabled? && params[:issn].present?

    @browzine = Browzine.lookup(issn: params[:issn])
  end

  private

  def expected_params?
    params[:type].present? && params[:identifier].present?
  end
end
