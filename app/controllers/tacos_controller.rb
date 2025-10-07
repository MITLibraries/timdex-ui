class TacosController < ApplicationController
  layout false

  def analyze
    return unless ApplicationHelper.tacos_enabled?

    Tacos.analyze(params[:q])
  end
end
