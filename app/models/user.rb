class User < ApplicationRecord
  include User::Deactivatable
  include User::EmailAddressChangeable

  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :nullify

  normalizes :email, with: ->(v) { v.strip.downcase.presence }

  after_create :ensure_default_team

  def ensure_default_team
    return if teams.any?
    Team.create_with_owner(
      team_attrs: { name: "#{email}'s Workspace" },
      owner: self
    )
  end

  def admin?
    # Add your admin email(s) here
    %w[admin@example.com].include?(email)
  end

  def personal_team
    owned_teams.find_by(kind: :personal) || owned_teams.first || teams.first
  end

  def default_team
    teams.joins(:memberships)
      .where(memberships: { user_id: id, status: :active })
      .order("memberships.created_at")
      .first
  end

  def display_id
    name.present? ? name : email
  end

  def send_magic_link(purpose: :sign_in)
    magic_links.create!(purpose: purpose).tap do |ml|
      MagicLinkMailer.sign_in_instructions(ml).deliver_later
    end
  end

  def active_for_passwordless_authentication?
    deleted_at.nil? && deactivated_at.nil?
  end

  def inactive_message
    if deactivated_at.present?
      "This account has been deactivated."
    elsif deleted_at.present?
      "This account has been deleted."
    else
      "This account is not active."
    end
  end
end
