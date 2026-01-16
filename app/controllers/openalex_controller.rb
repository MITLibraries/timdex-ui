class OpenalexController < ApplicationController
  layout false

  def work
    return unless Openalex.enabled? && expected_params?

    @openalex = Openalex.work(identifier_type: params[:type], identifier: params[:identifier])
  end

  private

  def expected_params?
    params[:type].present? && params[:identifier].present?
  end
end
