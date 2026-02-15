module User::Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
    scope :deactivated, -> { where.not(deactivated_at: nil) }
  end

  def deactivate!
    transaction do
      update!(deactivated_at: Time.current)
      memberships.update_all(status: :disabled)
      sessions.destroy_all
    end
  end

  def deactivated?
    deactivated_at.present?
  end

  def active?
    !deactivated?
  end

  def reactivate!
    update!(deactivated_at: nil)
  end
end
