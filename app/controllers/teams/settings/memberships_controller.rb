module Teams
  module Settings
    class MembershipsController < BaseController
      before_action :ensure_can_manage_team

      def index
        @memberships = @team.memberships.includes(:user)
      end

      # Who may change what (Security, Oct 28):
      # - only the team owner changes a role, and only to admin or member (never owner: a second owner
      #   comes only from a real transfer);
      # - an admin may change only the status (active/disabled) of a plain member;
      # - nobody changes their own membership here, and nobody changes the owner's;
      # - an unknown role or status is refused with a message, never a 500.
      ASSIGNABLE_ROLES = %w[admin member].freeze
      ASSIGNABLE_STATUSES = %w[active disabled].freeze

      def update
        membership = @team.memberships.find(params[:id])
        refusal = update_refusal(membership, membership_params)

        if refusal
          redirect_to settings_memberships_path(@team), alert: refusal
        else
          membership.update!(membership_params.slice(:role, :status))
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

      # nil when the change is allowed, else the message to show. A value equal to the current one is not a change.
      def update_refusal(membership, attrs)
        actor = @team.memberships.find_by(user: current_user)
        role = attrs[:role].to_s if attrs.key?(:role)
        status = attrs[:status].to_s if attrs.key?(:status)
        role = nil if role == membership.role
        status = nil if status == membership.status

        return "Cannot change the team owner's settings" if membership.owner?
        return "You cannot change your own membership" if membership.user_id == current_user.id
        return "Unknown role" if role && !ASSIGNABLE_ROLES.include?(role)
        return "Unknown status" if status && !ASSIGNABLE_STATUSES.include?(status)
        return nil if actor&.owner?
        return "Only the team owner can change roles" if role
        return "Only the team owner can change an admin" unless membership.member?
        nil
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
