class StaticController < ApplicationController
  def style_guide; end

  def boolpref
    if params[:boolean_type].present?
      cookies[:boolean_type] = params[:boolean_type]
    else
      cookies.delete :boolean_type
    end

    redirect_back_or_to root_path
  end
end
