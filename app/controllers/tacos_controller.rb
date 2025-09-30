class TacosController < ApplicationController
  layout false

  def analyze
    return unless ApplicationHelper.tacos_enabled?

    Tacos.call(params[:q])
  end
end
