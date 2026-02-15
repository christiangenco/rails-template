# Skeleton for Phase 6
class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  belongs_to :owner, class_name: "User", optional: true

  def self.create_with_owner(team_attrs:, owner:)
    # Minimal implementation for Phase 5
    # Will be properly implemented in Phase 6
    create!(team_attrs.merge(owner: owner))
  end
end
