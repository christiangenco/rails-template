class Membership < ApplicationRecord
  belongs_to :team
  belongs_to :user

  enum :role, { owner: 0, admin: 1, member: 2 }
  enum :status, { active: 0, invited: 1, disabled: 2 }

  validates :team_id, uniqueness: { scope: :user_id }

  scope :active_members, -> { where(status: :active) }

  def can_manage_team?
    owner? || admin?
  end

  def can_manage_billing?
    owner?
  end
end
