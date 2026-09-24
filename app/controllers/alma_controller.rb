class AlmaController < ApplicationController
  layout false

  def sru
    return unless AlmaSru.enabled? && expected_params?

    # AlmaSru.lookup returns two independent signals used by the SRU partial:
    # - physical_availability: holdings/circulation statements for display
    # - electronic_availability: whether to show the Full-text options action
    #
    # A record can have one without the other, so we assign and render them separately.
    result = AlmaSru.lookup(params[:doc_id])
    @physical_availability = result[:physical_availability]
    @electronic_availability = result[:electronic_availability]
  end

  private

  def expected_params?
    params[:doc_id].present?
  end
end
