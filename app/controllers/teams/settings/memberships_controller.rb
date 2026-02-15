module Teams
  module Settings
    class MembershipsController < BaseController
      before_action :ensure_can_manage_team

      def index
        @memberships = @team.memberships.includes(:user)
      end

      def update
        membership = @team.memberships.find(params[:id])

        if membership.owner?
          redirect_to settings_memberships_path(@team), alert: "Cannot change the team owner's settings"
        else
          membership.update!(membership_params)
          redirect_to settings_memberships_path(@team), notice: "Member updated"
        end
      end

      def destroy
        membership = @team.memberships.find(params[:id])

        if membership.owner?
          redirect_to settings_memberships_path(@team), alert: "Cannot remove the team owner"
        elsif membership.user == current_user
          redirect_to settings_memberships_path(@team), alert: "Cannot remove yourself"
        else
          membership.destroy!
          redirect_to settings_memberships_path(@team), notice: "Member removed"
        end
      end

      private

      def membership_params
        params.require(:membership).permit(:role, :status)
      end

      def ensure_can_manage_team
        membership = @team.memberships.find_by(user: current_user)
        unless membership&.can_manage_team?
          redirect_to root_path(team_id: @team.id), alert: "You don't have permission to manage team members"
        end
      end
    end
  end
end
