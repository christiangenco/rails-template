module Teams
  module Settings
    class GeneralController < BaseController
      before_action :ensure_can_manage_team

      def show
      end

      def update
        if @team.update(team_params)
          redirect_to settings_general_path(@team), notice: "Settings updated"
        else
          render :show, status: :unprocessable_entity
        end
      end

      private

      def team_params
        params.require(:team).permit(:name, :timezone)
      end

      def ensure_can_manage_team
        membership = @team.memberships.find_by(user: current_user)
        unless membership&.can_manage_team?
          redirect_to root_path(team_id: @team.id), alert: "You don't have permission to manage team settings"
        end
      end
    end
  end
end
