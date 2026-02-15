class DevErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    raise ActiveRecord::RecordNotFound
  end

  def internal_error
    raise "Test 500 error"
  end
end
