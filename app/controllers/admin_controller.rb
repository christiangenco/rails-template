class AdminController < ApplicationController
  before_action :ensure_admin

  def impersonate
    user = User.find(params[:id])
    session[:true_user_id] = true_user.id
    session[:impersonated_user_id] = user.id
    redirect_to root_path, notice: "Now impersonating #{user.email}"
  end

  def stop_impersonating
    session.delete(:impersonated_user_id)
    session.delete(:true_user_id)
    redirect_to root_path, notice: "Stopped impersonating"
  end
end
