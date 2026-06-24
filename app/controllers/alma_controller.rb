class AlmaController < ApplicationController
  layout false

  def sru
    return unless AlmaSru.enabled? && expected_params?

    @availability = AlmaSru.lookup(params[:doc_id])
  end

  private

  def expected_params?
    params[:doc_id].present?
  end
end
