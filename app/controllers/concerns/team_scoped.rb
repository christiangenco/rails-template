module TeamScoped
  extend ActiveSupport::Concern

  included do
    before_action :require_team
    before_action :require_team_membership, unless: :allow_public_access?
  end

  private

  def require_team
    return if allow_public_access?

    unless Current.team
      if authenticated?
        if current_user.default_team
          redirect_to root_path(team_id: current_user.default_team.id)
        else
          redirect_to root_path, alert: "You need to be part of a team."
        end
      else
        redirect_to new_session_path, alert: "Please sign in to continue."
      end
    end
  end

  def require_team_membership
    return unless authenticated?
    return unless Current.team

    unless Current.team.users.include?(current_user)
      redirect_path = current_user.default_team ? root_path(team_id: current_user.default_team.id) : root_path
      redirect_to redirect_path, alert: "You don't have access to that team."
    end
  end

  def allow_public_access?
    false
  end
end
