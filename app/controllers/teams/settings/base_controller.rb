module Teams
  module Settings
    class BaseController < ApplicationController
      include TeamScoped

      before_action :set_team

      private

      def set_team
        @team = Current.team
      end
    end
  end
end
