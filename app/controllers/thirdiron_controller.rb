class ThirdironController < ApplicationController
  layout false

  def libkey
    return unless Libkey.enabled? && expected_params?

    @libkey = Libkey.lookup(type: params[:type], identifier: params[:identifier])
  end

  private

  def expected_params?
    params[:type].present? && params[:identifier].present?
  end
end
