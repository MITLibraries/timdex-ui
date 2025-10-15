class TacosController < ApplicationController
  layout false

  def analyze
    return unless ApplicationHelper.tacos_enabled?

    tacos_response = Tacos.analyze(params[:q])

    # Suggestions return as an array but we don't want to display more than one.
    # We may want to have a "priority" system in the future to determine which suggestion to show.
    @suggestions = tacos_response['data']['logSearchEvent']['detectors']['suggestedResources'].first
  end
end
