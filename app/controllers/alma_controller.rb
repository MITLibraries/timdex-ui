class AlmaController < ApplicationController
  layout false

  def sru
    return unless AlmaSru.enabled? && expected_params?

    result = AlmaSru.lookup(params[:doc_id])
    @availability = result[:availability]
    @alma_e = result[:alma_e]
  end

  private

  def expected_params?
    params[:doc_id].present?
  end
end
