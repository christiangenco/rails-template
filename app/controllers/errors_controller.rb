class ErrorsController < ApplicationController
  allow_unauthenticated_access

  # Error pages are HTML only. A request for /secrets.json or /x.yml (scanners do this) would otherwise
  # look for a .json or .yml view, find none, and turn a 404 into a 500 (Security, Oct 27, #2113).
  before_action { request.format = :html }

  def not_found
    render status: :not_found
  end

  def unprocessable
    render status: :unprocessable_entity
  end

  def internal_error
    render status: :internal_server_error
  end
end
