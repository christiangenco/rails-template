class UiTestController < ApplicationController
  def index
    # Handle flash messages from URL params
    flash.now[:notice] = params[:notice] if params[:notice].present?
    flash.now[:alert] = params[:alert] if params[:alert].present?
  end
end
