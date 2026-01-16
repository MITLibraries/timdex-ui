class BeaconController < ApplicationController
  def outbound
    ab_finished(:result_format)
    head :ok
  end
end
