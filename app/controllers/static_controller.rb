class StaticController < ApplicationController
  def style_guide; end

  def results
    @internal = internal_params
  end

  private

    # TODO: More rigorously handle the validation of parameters for this request. The @internal instance variable will
    # then be routed through the to_query method for the request to the internal search handler.
    #
    # This is duplicative of the validation in the search controller, but there should be a way to abstract that
    # validation to a shared method somewhere.
    def internal_params
      params.permit(:q, :advanced, :citation)
        .to_h { |key, value| [:"#{key}", value] }
    end
end
