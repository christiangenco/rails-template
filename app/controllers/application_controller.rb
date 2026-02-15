class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include Pagy::Backend
  include Authentication

  helper_method :current_user, :true_user, :admin_impersonating?

  before_action :set_current_team

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def current_user
    if session[:impersonated_user_id]
      @current_user ||= User.find_by(id: session[:impersonated_user_id])
    else
      Current.user
    end
  end

  def true_user
    @true_user ||= User.find_by(id: session[:true_user_id]) || current_user
  end

  def admin_impersonating?
    current_user && true_user != current_user
  end

  def ensure_admin
    unless true_user&.admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end

  def render_not_found
    render "errors/not_found", status: :not_found, layout: "application"
  end

  def set_current_team
    return unless params[:team_id].present?
    team = Team.find_by(id: params[:team_id])
    Current.team = team if team
  end
end
