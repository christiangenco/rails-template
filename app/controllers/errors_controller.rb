class ErrorsController < ApplicationController
  allow_unauthenticated_access

  # Error pages change no state and never need request data. The exceptions app re-dispatches the
  # ORIGINAL request (its malformed body, query string and content type included); skip our inherited
  # callbacks that would read params or write session on that path.
  skip_forgery_protection
  skip_before_action :set_analytics_user, :persist_utm_params

  # Last resort: if anything still raises ActionController::BadRequest (bad query string or body),
  # answer the 404 page with status 400 instead of falling through to the failsafe 500.
  rescue_from ActionController::BadRequest do
    render "errors/not_found", status: :bad_request
  end

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
