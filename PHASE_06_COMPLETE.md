# Phase 6: Teams & Memberships - Implementation Complete

## Summary

Successfully implemented team-based multi-tenancy with auto-created personal teams, memberships with roles, and team settings pages.

## What Was Implemented

### 1. Database Migrations ✓

#### Teams Table
- `name` (string) - Team name
- `owner_id` (references users) - Team owner
- `kind` (string, default: "personal") - Team type (personal/organization)
- `timezone` (string) - Team timezone
- Index on `owner_id`

#### Memberships Table
- `team_id` (references teams) - Team reference
- `user_id` (references users) - User reference
- `role` (integer, default: 0) - User role (owner/admin/member)
- `status` (integer, default: 0) - Membership status (active/invited/disabled)
- Unique index on `[team_id, user_id]`

### 2. Models ✓

#### Team Model (`app/models/team.rb`)
- **Associations**: 
  - `belongs_to :owner` (User, optional)
  - `has_many :memberships`
  - `has_many :users, through: :memberships`
- **Enums**: `kind` (personal, organization)
- **Validations**:
  - Name presence
  - Timezone inclusion in ActiveSupport::TimeZone::MAPPING
- **Scopes**: `active` - teams with active memberships
- **Methods**:
  - `time_zone` - Returns TimeZone object, defaults to Eastern Time
  - `display_name` - Returns name or owner's display_id
  - `self.create_with_owner` - Creates team and owner membership in transaction

#### Membership Model (`app/models/membership.rb`)
- **Associations**: 
  - `belongs_to :team`
  - `belongs_to :user`
- **Enums**: 
  - `role` (owner: 0, admin: 1, member: 2)
  - `status` (active: 0, invited: 1, disabled: 2)
- **Validations**: Unique team_id scoped to user_id
- **Scopes**: `active_members`
- **Methods**:
  - `can_manage_team?` - True for owner/admin
  - `can_manage_billing?` - True for owner only

#### User Model Updates (`app/models/user.rb`)
- **Auto-team Creation**: `after_create :ensure_default_team` callback
- Creates personal team with name "{email}'s Workspace"
- **Methods**:
  - `default_team` - First active team by membership creation
  - `personal_team` - User's personal team (kind: personal)

### 3. Controllers ✓

#### TeamScoped Concern (`app/controllers/concerns/team_scoped.rb`)
- `require_team` - Ensures Current.team is set
- `require_team_membership` - Ensures user has access to team
- `allow_public_access?` - Override in controllers for public pages

#### Settings Controllers
All under `Teams::Settings` namespace:

**BaseController** - Includes TeamScoped, sets @team from Current.team

**GeneralController** - Team settings
- `show` - Display team settings form
- `update` - Update team name and timezone
- Requires `can_manage_team?` permission

**MembershipsController** - Team member management
- `index` - List all team members
- `update` - Change member role
- `destroy` - Remove member
- Prevents removing owner or self
- Prevents changing owner role
- Requires `can_manage_team?` permission

### 4. Views ✓

#### Settings Header (`app/views/teams/settings/_header.html.erb`)
- Displays team name
- Horizontal tabs: General, Team
- Uses `horizontal_tabs` partial from Phase 4

#### General Settings (`app/views/teams/settings/general/show.html.erb`)
- White card with form
- Team name text field
- Timezone select (US zones only)
- "Save Changes" button
- Uses `tailwind_form_for` helper

#### Memberships Index (`app/views/teams/settings/memberships/index.html.erb`)
- White card with member list
- Each member shows:
  - Gravatar (40px)
  - Name/email
  - Role badge (blue=owner, purple=admin, gray=member)
  - Role dropdown (for non-owners)
  - Remove button with confirmation (for non-owners)
- Owner cannot be modified or removed

### 5. Routes ✓

```ruby
scope "/teams/:team_id", constraints: { team_id: /\d+/ } do
  namespace :settings, module: "teams/settings" do
    resource :general, only: [:show, :update]
    resources :memberships, only: [:index, :update, :destroy]
  end
  get "settings", to: redirect { |params, _| "/teams/#{params[:team_id]}/settings/general" }
end
```

**Named Routes**:
- `settings_general_path(@team)` → `/teams/:id/settings/general`
- `settings_memberships_path(@team)` → `/teams/:id/settings/memberships`
- `settings_membership_path(@team, @membership)` → `/teams/:id/settings/memberships/:id`
- `settings_path(@team)` → Redirects to general settings

### 6. Navigation Updates ✓

Updated `app/views/layouts/_navigation.html.erb`:

- **Team Switcher** (shows when user has > 1 team)
  - Displays current team name using `display_name`
  - Dropdown lists all user's teams
  - Highlights current team
  - Links to `root_path(team_id: team.id)`

- **Account Dropdown**
  - "Team Settings" → `settings_general_path(team)`
  - "Team Members" → `settings_memberships_path(team)`
  - "Sign Out" → `session_path` (DELETE)

- **Login Button** → `new_session_path`

- **Mobile Menu** - Same links as desktop

### 7. Authentication Updates ✓

Updated `app/controllers/concerns/authentication.rb`:

```ruby
def default_authenticated_path
  if Current.user&.default_team
    root_path(team_id: Current.user.default_team.id)
  else
    root_path
  end
end
```

After sign in, users are redirected to their default team context.

### 8. Helpers ✓

Added to `app/helpers/application_helper.rb`:
- `gravatar_url_for` - Alias for `gravatar_url`

## Verification Results

All verification checks passed ✓

### Model Tests
- ✓ New user auto-creates personal team
- ✓ Team has correct name format: "{email}'s Workspace"
- ✓ Team kind defaults to "personal"
- ✓ Owner membership created with role: owner, status: active
- ✓ Team.display_name returns team name or owner email
- ✓ Team.time_zone returns TimeZone object
- ✓ Membership.can_manage_team? true for owner/admin
- ✓ Membership.can_manage_billing? true for owner only
- ✓ User.default_team returns first active team
- ✓ User.personal_team returns personal team
- ✓ Team.active scope returns teams with active memberships
- ✓ Multiple users can be added to same team

### View Tests
- ✓ General settings view exists with name and timezone fields
- ✓ Memberships index exists with gravatars and role badges
- ✓ Settings header partial exists with horizontal tabs

### Controller Tests
- ✓ BaseController exists and includes TeamScoped
- ✓ GeneralController exists with show/update actions
- ✓ MembershipsController exists with index/update/destroy actions
- ✓ TeamScoped concern exists with team authentication

### Navigation Tests
- ✓ Team switcher uses Current.team fallback
- ✓ Team Settings link points to settings_general_path
- ✓ Team Members link points to settings_memberships_path
- ✓ Sign Out button points to session_path
- ✓ Login link points to new_session_path
- ✓ Uses team.display_name method

### Authentication Tests
- ✓ default_authenticated_path redirects to team context

## Files Created

```
app/models/team.rb
app/models/membership.rb
app/controllers/concerns/team_scoped.rb
app/controllers/teams/settings/base_controller.rb
app/controllers/teams/settings/general_controller.rb
app/controllers/teams/settings/memberships_controller.rb
app/views/teams/settings/_header.html.erb
app/views/teams/settings/general/show.html.erb
app/views/teams/settings/memberships/index.html.erb
db/migrate/XXXXXX_create_teams.rb
db/migrate/XXXXXX_create_memberships.rb
```

## Files Modified

```
app/models/user.rb (updated default_team query)
app/views/layouts/_navigation.html.erb (team switcher, settings links)
app/controllers/concerns/authentication.rb (default_authenticated_path)
app/helpers/application_helper.rb (gravatar_url_for alias)
config/routes.rb (team-scoped settings routes)
```

## Usage Examples

### Creating Teams
```ruby
# Auto-created on user signup
user = User.create!(email: "user@example.com")
user.teams.count # => 1
user.personal_team.name # => "user@example.com's Workspace"

# Manual creation with owner
team = Team.create_with_owner(
  team_attrs: { name: "Acme Inc", kind: :organization },
  owner: user
)
```

### Managing Memberships
```ruby
# Add member
team.memberships.create!(user: other_user, role: :member, status: :active)

# Add admin
team.memberships.create!(user: admin_user, role: :admin, status: :active)

# Check permissions
membership.can_manage_team? # true for owner/admin
membership.can_manage_billing? # true for owner only
```

### Team Settings URLs
```erb
<%= link_to "Settings", settings_general_path(@team) %>
<%= link_to "Members", settings_memberships_path(@team) %>
```

## Next Steps

Phase 7 will add:
- Profile page for users
- Email change with verification flow
- Password-less account management

## Notes

- Team kind enum supports "personal" and "organization" for future expansion
- Membership status enum includes "invited" for future invitation flow
- Three-tier role system: owner (full control), admin (manage team), member (use resources)
- Timezone defaults to Eastern Time if not set
- Team switcher only shows when user has multiple teams
- All team operations are team-scoped via TeamScoped concern
- Owner cannot be removed or have their role changed
- Users cannot remove themselves from teams
