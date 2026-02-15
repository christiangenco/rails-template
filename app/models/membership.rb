# Skeleton for Phase 6
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :team

  enum :role, { member: 0, admin: 1 }
  enum :status, { active: 0, disabled: 1 }
end
