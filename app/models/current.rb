class Current < ActiveSupport::CurrentAttributes
  attribute :user, :team, :session

  def session=(value)
    super(value)
    self.user = session&.user
  end
end
