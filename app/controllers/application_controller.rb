class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include Pagy::Backend
  include Authentication

  helper_method :current_user

  before_action :set_current_team

  private

  def current_user
    Current.user
  end

  def set_current_team
    return unless params[:team_id].present?
    team = Team.find_by(id: params[:team_id])
    Current.team = team if team
  end
end
