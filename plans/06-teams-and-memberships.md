# Phase 6: Teams & Memberships

## Goal

Implement team-based multi-tenancy. Every user gets a personal team on signup. All application records are owned by a team. Users can be invited to teams with different access levels.

## Steps

### 6.1 Generate Models

#### Team

```bash
bin/rails generate model Team \
  name:string \
  owner:references{polymorphic}:null \
  kind:string \
  timezone:string
```

Edit migration:
- `owner` should be `references :users, foreign_key: true, null: true` (not polymorphic)
- Add `default: "personal"` to `kind`
- Add index on `owner_id`

#### Membership

```bash
bin/rails generate model Membership \
  team:references \
  user:references \
  role:integer \
  status:integer
```

Edit migration:
- Add `default: 0` to `role` (owner)
- Add `default: 0` to `status` (active)
- Add unique index: `add_index :memberships, [:team_id, :user_id], unique: true`

Run `bin/rails db:migrate`.

### 6.2 Team Model

```ruby
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
```

### 6.3 Membership Model

```ruby
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
```

Note: This adds `admin: 1` role compared to Fileinbox which only had owner and member. This gives us a three-tier system: owner (full control), admin (can manage team settings and members), member (can use team resources).

### 6.4 User Model Updates

The User model from Phase 5 already has the team associations. Now ensure `ensure_default_team` works:

```ruby
after_create :ensure_default_team

def ensure_default_team
  return if teams.any?
  Team.create_with_owner(
    team_attrs: { name: "#{email}'s Workspace" },
    owner: self
  )
end

def default_team
  teams.joins(:memberships)
    .where(memberships: { user_id: id, status: :active })
    .order("memberships.created_at")
    .first
end

def personal_team
  owned_teams.find_by(kind: :personal) || owned_teams.first || teams.first
end
```

### 6.5 TeamScoped Concern

Create `app/controllers/concerns/team_scoped.rb`:

```ruby
module TeamScoped
  extend ActiveSupport::Concern

  included do
    before_action :require_team
    before_action :require_team_membership, unless: :allow_public_access?
  end

  private

  def require_team
    return if allow_public_access?

    unless Current.team
      if authenticated?
        if current_user.default_team
          redirect_to root_path(team_id: current_user.default_team.id)
        else
          redirect_to root_path, alert: "You need to be part of a team."
        end
      else
        redirect_to new_session_path, alert: "Please sign in to continue."
      end
    end
  end

  def require_team_membership
    return unless authenticated?
    return unless Current.team

    unless Current.team.users.include?(current_user)
      redirect_path = current_user.default_team ? root_path(team_id: current_user.default_team.id) : root_path
      redirect_to redirect_path, alert: "You don't have access to that team."
    end
  end

  def allow_public_access?
    false
  end
end
```

### 6.6 Team Settings Controllers

#### BaseController

Create `app/controllers/teams/settings/base_controller.rb`:

```ruby
module Teams
  module Settings
    class BaseController < ApplicationController
      include TeamScoped

      before_action :set_team

      private

      def set_team
        @team = Current.team
      end
    end
  end
end
```

#### GeneralController

Create `app/controllers/teams/settings/general_controller.rb`:

```ruby
module Teams
  module Settings
    class GeneralController < BaseController
      before_action :ensure_can_manage_team

      def show
      end

      def update
        if @team.update(team_params)
          redirect_to settings_general_path(@team), notice: "Settings updated"
        else
          render :show, status: :unprocessable_entity
        end
      end

      private

      def team_params
        params.require(:team).permit(:name, :timezone)
      end

      def ensure_can_manage_team
        membership = @team.memberships.find_by(user: current_user)
        unless membership&.can_manage_team?
          redirect_to root_path(team_id: @team.id), alert: "You don't have permission to manage team settings"
        end
      end
    end
  end
end
```

#### MembershipsController

Create `app/controllers/teams/settings/memberships_controller.rb`:

```ruby
module Teams
  module Settings
    class MembershipsController < BaseController
      before_action :ensure_can_manage_team

      def index
        @memberships = @team.memberships.includes(:user)
      end

      def update
        membership = @team.memberships.find(params[:id])

        if membership.owner?
          redirect_to settings_memberships_path(@team), alert: "Cannot change the team owner's settings"
        else
          membership.update!(membership_params)
          redirect_to settings_memberships_path(@team), notice: "Member updated"
        end
      end

      def destroy
        membership = @team.memberships.find(params[:id])

        if membership.owner?
          redirect_to settings_memberships_path(@team), alert: "Cannot remove the team owner"
        elsif membership.user == current_user
          redirect_to settings_memberships_path(@team), alert: "Cannot remove yourself"
        else
          membership.destroy!
          redirect_to settings_memberships_path(@team), notice: "Member removed"
        end
      end

      private

      def membership_params
        params.require(:membership).permit(:role, :status)
      end

      def ensure_can_manage_team
        membership = @team.memberships.find_by(user: current_user)
        unless membership&.can_manage_team?
          redirect_to root_path(team_id: @team.id), alert: "You don't have permission to manage team members"
        end
      end
    end
  end
end
```

### 6.7 Team Settings Views

#### Settings Header

Create `app/views/teams/settings/_header.html.erb`:

```erb
<div class="mb-6">
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
    <%= @team.display_name %> Settings
  </h1>
</div>

<%= render "shared/horizontal_tabs",
  tabs: [
    { label: "General", path: settings_general_path(@team), icon: "cog-6-tooth" },
    { label: "Team", path: settings_memberships_path(@team), icon: "users" },
  ],
  current_path: request.path %>
```

#### General Settings (show.html.erb)

White card with team name text field, timezone select (US zones), and "Save Changes" button. Uses `tailwind_form_for`.

#### Memberships Index (index.html.erb)

White card listing team members:
- Gravatar, email, role badge (Owner/Admin/Member)
- For non-owners: role dropdown to change role, remove button with confirm
- Owner cannot be removed or changed

### 6.8 Routes

```ruby
# Team-scoped routes
scope "/teams/:team_id", constraints: { team_id: /\d+/ } do
  namespace :settings, module: "teams/settings" do
    resource :general, only: [:show, :update], controller: "general"
    resources :memberships, only: [:index, :update, :destroy]
  end
  get "settings", to: redirect { |params, _| "/teams/#{params[:team_id]}/settings/general" }
end
```

### 6.9 Update Navigation

Update `_navigation.html.erb` to show:
- Team switcher dropdown when user has multiple teams
- Team Settings link in the account dropdown
- Team Members link in the account dropdown

### 6.10 Update default_authenticated_path

In the Authentication concern, `default_authenticated_path` should redirect to:
```ruby
def default_authenticated_path
  if Current.user&.default_team
    root_path(team_id: Current.user.default_team.id)
  else
    root_path
  end
end
```

(This will eventually point to the Posts index once that exists in Phase 10.)

## Verification

- New user signs up → personal team auto-created
- Team settings page shows General and Team tabs
- Can rename team, change timezone
- Memberships page lists the owner
- Owner cannot be removed
- Non-owners can be removed with confirmation
- Team switcher appears when user has multiple teams
- Accessing another team's settings redirects with "You don't have access"

## Files Created/Modified

- `app/models/team.rb`
- `app/models/membership.rb`
- `app/models/user.rb` (update)
- `app/controllers/concerns/team_scoped.rb`
- `app/controllers/teams/settings/base_controller.rb`
- `app/controllers/teams/settings/general_controller.rb`
- `app/controllers/teams/settings/memberships_controller.rb`
- `app/views/teams/settings/_header.html.erb`
- `app/views/teams/settings/general/show.html.erb`
- `app/views/teams/settings/memberships/index.html.erb`
- `app/views/layouts/_navigation.html.erb` (update)
- `config/routes.rb` (update)
- `db/migrate/*_create_teams.rb`
- `db/migrate/*_create_memberships.rb`
