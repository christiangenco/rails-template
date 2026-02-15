class Team < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  enum :kind, { personal: "personal", organization: "organization" }

  validates :name, presence: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone::MAPPING.keys }, allow_blank: true

  scope :active, -> { joins(:memberships).where(memberships: { status: :active }).distinct }

  def time_zone
    return ActiveSupport::TimeZone["Eastern Time (US & Canada)"] if timezone.blank?
    ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  class << self
    def create_with_owner(team_attrs:, owner:)
      transaction do
        team = create!(team_attrs.merge(owner: owner, kind: :personal))
        Membership.create!(team: team, user: owner, role: :owner, status: :active)
        team
      end
    end
  end

  def display_name
    name.presence || owner&.display_id || "Unnamed Team"
  end
end
