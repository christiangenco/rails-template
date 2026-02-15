class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if current_user
      redirect_to posts_path(team_id: current_user.default_team&.id)
      return
    end

    render "index"
  end
end
