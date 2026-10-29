require "test_helper"

# Who may change a team membership (Security, Oct 28). Every test checks the STORED role/status after the request.
class Teams::Settings::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner@example.com")
    @team = Team.create!(name: "Acme", owner: @owner, kind: :organization)
    @owner_m = Membership.create!(team: @team, user: @owner, role: :owner, status: :active)
    @admin = User.create!(email: "admin@example.com")
    @admin_m = Membership.create!(team: @team, user: @admin, role: :admin, status: :active)
    @admin2 = User.create!(email: "admin2@example.com")
    @admin2_m = Membership.create!(team: @team, user: @admin2, role: :admin, status: :active)
    @member = User.create!(email: "member@example.com")
    @member_m = Membership.create!(team: @team, user: @member, role: :member, status: :active)
    @member2 = User.create!(email: "member2@example.com")
    @member2_m = Membership.create!(team: @team, user: @member2, role: :member, status: :active)
  end

  def sign_in(user)
    session = user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    ApplicationController.any_instance.stubs(:find_session_by_cookie).returns(session)
  end

  def patch_membership(membership, attrs, team: @team)
    patch settings_membership_path(team_id: team.id, id: membership.id), params: { membership: attrs }
  end

  test "T1: an admin cannot make a member the owner" do
    sign_in @admin
    patch_membership @member_m, { role: "owner" }
    assert_redirected_to settings_memberships_path(@team)
    assert_equal "member", @member_m.reload.role
  end

  test "T2: an admin cannot change their own membership" do
    sign_in @admin
    patch_membership @admin_m, { role: "owner" }
    assert_equal "admin", @admin_m.reload.role
    sign_in @member
    patch_membership @member_m, { role: "admin" }
    assert_equal "member", @member_m.reload.role
    sign_in @owner
    patch_membership @owner_m, { role: "member" }
    assert_equal "owner", @owner_m.reload.role
  end

  test "T3: an admin cannot change or disable another admin; the owner can" do
    sign_in @admin
    patch_membership @admin2_m, { role: "member" }
    assert_equal "admin", @admin2_m.reload.role
    patch_membership @admin2_m, { status: "disabled" }
    assert_equal "active", @admin2_m.reload.status

    sign_in @owner
    patch_membership @admin2_m, { role: "member" }
    assert_equal "member", @admin2_m.reload.role
    patch_membership @admin2_m, { status: "disabled" }
    assert_equal "disabled", @admin2_m.reload.status
  end

  test "T3b: an admin may disable a plain member but not change a member's role" do
    sign_in @admin
    patch_membership @member_m, { role: "admin" }
    assert_equal "member", @member_m.reload.role
    patch_membership @member_m, { status: "disabled" }
    assert_equal "disabled", @member_m.reload.status
    patch_membership @member_m, { role: "member", status: "active" }
    assert_equal "active", @member_m.reload.status
  end

  test "T4: the owner sets admin; owner, unknown words and numbers are refused without a 500" do
    sign_in @owner
    patch_membership @member_m, { role: "admin" }
    assert_equal "admin", @member_m.reload.role

    [ "owner", "superuser", "0", 0, "" ].each do |value|
      patch_membership @member2_m, { role: value }
      assert_redirected_to settings_memberships_path(@team), "role #{value.inspect}"
      assert_equal "member", @member2_m.reload.role, "role #{value.inspect}"
    end
    [ "invited", "banned", "2" ].each do |value|
      patch_membership @member2_m, { status: value }
      assert_redirected_to settings_memberships_path(@team), "status #{value.inspect}"
      assert_equal "active", @member2_m.reload.status, "status #{value.inspect}"
    end
  end

  test "T5: a plain member cannot update anyone, and another team's membership changes nothing" do
    sign_in @member
    patch_membership @member2_m, { status: "disabled" }
    assert_response :redirect
    assert_equal "active", @member2_m.reload.status

    other_owner = User.create!(email: "other@example.com")
    other_team = Team.create!(name: "Other", owner: other_owner, kind: :organization)
    Membership.create!(team: other_team, user: other_owner, role: :owner, status: :active)
    other_m = Membership.create!(team: other_team, user: User.create!(email: "x@example.com"), role: :member, status: :active)

    sign_in @owner
    patch_membership other_m, { role: "admin" }
    assert_response :not_found
    assert_equal "member", other_m.reload.role
  end

  test "strong parameters ignore user_id and team_id" do
    sign_in @owner
    patch_membership @member_m, { role: "admin", user_id: @owner.id, team_id: 999 }
    @member_m.reload
    assert_equal "admin", @member_m.role
    assert_equal @member.id, @member_m.user_id
    assert_equal @team.id, @member_m.team_id
  end
end
