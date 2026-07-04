# config valid for current version and patch releases of Capistrano
lock "~> 3.17.1"



set :application, "blog"
set :repo_url, "git@github.com:tyrant/blog.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
#set :deploy_to, "/home/app-user/blog"
set :deploy_to, '/home/noob/blog'

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/credentials/production.key', '.env.production'

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "tmp/medium_sync_chrome_profile", "app/assets/builds", "public/system", '.bundle', "node_modules"

# Default value for default_env is {}
set :default_env, { 
  path: "/home/noob/.nodenv/shims:/opt/ruby/bin:$PATH",
  NODE_OPTIONS: "--openssl-legacy-provider"
}

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :rbenv_ruby, '4.0.5'
set :rbenv_path, '/home/noob/.rbenv'

namespace :deploy do
  namespace :check do
    before :linked_files, :set_production_key do
      on roles(:app), in: :sequence, wait: 10 do
        %w[master credentials/production].each do |file|
          unless test("[ -f #{shared_path}/config/#{file}.key ]")
            upload! "config/#{file}.key", "#{shared_path}/config/#{file}.key"
          end
        end
      end
    end
  end
end

# comfy_vendor.js lives in the (linked) builds dir, so refresh shared from the
# just-deployed commit before assets:precompile reads it. Must run AFTER git:update
# — doing it in deploy:check copies the previous deploy's stale bundle.
before "deploy:assets:precompile", :copy_comfy_vendor_js do
  on roles(:app) do
    execute :mkdir, "-p", "#{shared_path}/app/assets/builds"
    within repo_path do
      execute :git, "show", "#{fetch(:branch)}:app/assets/builds/comfy_vendor.js", ">", "#{shared_path}/app/assets/builds/comfy_vendor.js"
    end
  end
end

# Restart the SolidQueue worker so it runs the just-deployed code. Tolerant: the
# deploy won't fail if the (user) systemd service isn't installed yet.
namespace :solid_queue do
  task :restart do
    on roles(:app) do
      execute "XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user restart blizzard-jobs.service || true"
    end
  end
end
after "deploy:published", "solid_queue:restart"
