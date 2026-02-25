# Skip Tailwind CSS build during Docker image builds.
# Tailwind v4's Rust filesystem scanner produces incomplete output when run
# inside Docker's overlayfs during build. Instead, we pre-build tailwind.css
# on the host via .kamal/hooks/pre-build and COPY it into the Docker image.
if ENV["SKIP_TAILWIND_BUILD"]
  Rake::Task["tailwindcss:build"].clear
  namespace :tailwindcss do
    task build: :environment do
      puts "Skipping Tailwind build (SKIP_TAILWIND_BUILD is set, using pre-built CSS)"
    end
  end
end
