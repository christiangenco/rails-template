if Rails.env.development?
  puts "Seeding development data..."

  # Create admin user
  admin = User.find_or_create_by!(email: "admin@example.com") do |u|
    u.name = "Admin User"
  end

  # Create a few example posts
  team = admin.default_team
  3.times do |i|
    team.posts.find_or_create_by!(title: "Example Post #{i + 1}") do |post|
      post.created_by = admin
      post.body = "<p>This is example post #{i + 1}. It was seeded for development.</p>"
    end
  end

  puts "Done! Admin user: admin@example.com"
end
