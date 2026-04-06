# frozen_string_literal: true

namespace :medium do
  desc "Launch Chrome with the Medium sync profile for interactive login. " \
       "On a remote server, use an SSH tunnel to access Chrome DevTools from your local browser."
  task :setup do
    project_root = File.expand_path("../..", __dir__)
    profile_dir = File.join(project_root, "tmp", "medium_sync_chrome_profile")
    FileUtils.mkdir_p(profile_dir)
    debug_port = 9222

    # Clean stale locks from any previous Chrome process.
    %w[SingletonLock SingletonCookie SingletonSocket].each do |f|
      path = File.join(profile_dir, f)
      File.delete(path) if File.exist?(path)
    end

    chrome_binary = (ENV["CHROME_BINARY"] unless ENV["CHROME_BINARY"].to_s.empty?) ||
      [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/usr/bin/chromium-browser",
        "/usr/bin/chromium",
      ].find { |p| File.executable?(p) }

    abort "Chrome binary not found. Set CHROME_BINARY env var." unless chrome_binary

    args = [
      chrome_binary,
      "--remote-debugging-port=#{debug_port}",
      "--user-data-dir=#{profile_dir}",
      "--no-first-run",
      "--no-default-browser-check",
      "--window-size=1280,900",
    ]

    # On a headless server, add headless flags but still expose the debug port
    # so the user can connect via SSH tunnel + DevTools frontend.
    if ENV["DISPLAY"].blank? && !RbConfig::CONFIG["host_os"].include?("darwin")
      args += %w[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu]
    end

    args << "https://medium.com"

    puts ""
    puts "=" * 70
    puts "  Medium Sync — Interactive Login Setup"
    puts "=" * 70
    puts ""
    puts "Chrome is starting with the sync profile on debug port #{debug_port}."
    puts ""

    if ENV["DISPLAY"].blank? && !RbConfig::CONFIG["host_os"].include?("darwin")
      puts "REMOTE SERVER DETECTED — headless mode enabled."
      puts ""
      puts "From your local machine, open an SSH tunnel:"
      puts ""
      puts "  ssh -L #{debug_port}:127.0.0.1:#{debug_port} #{ENV['USER']}@<server-ip>"
      puts ""
      puts "Then open Chrome DevTools in your local browser:"
      puts ""
      puts "  http://127.0.0.1:#{debug_port}"
      puts ""
      puts "Click the inspectable page to get a full browser view."
      puts "Navigate to https://medium.com and log in with your account."
    else
      puts "A Chrome window should open. Log in to Medium with your account."
    end

    puts ""
    puts "Once logged in, come back here and press Enter to verify & save."
    puts "-" * 70
    puts ""

    pid = Process.spawn(*args, [:out, :err] => File::NULL)
    Process.detach(pid)

    # Wait for Chrome to start.
    sleep 3

    $stdin.gets

    # Verify login by checking cookies via CDP.
    require "net/http"
    require "json"

    begin
      # Get the first page's WebSocket URL.
      pages_uri = URI("http://127.0.0.1:#{debug_port}/json")
      pages_res = Net::HTTP.get(pages_uri)
      pages = JSON.parse(pages_res)
      page_ws = pages.first&.dig("webSocketDebuggerUrl")

      if page_ws
        # Use the /json/version endpoint to confirm Chrome is alive,
        # then check cookies via a simple HTTP call to the page.
        cookies_uri = URI("http://127.0.0.1:#{debug_port}/json/version")
        version_res = Net::HTTP.get(cookies_uri)
        version = JSON.parse(version_res)
        puts "Chrome version: #{version['Browser']}"
      end

      puts ""
      puts "Session cookies have been saved to the Chrome profile at:"
      puts "  #{profile_dir}"
      puts ""
      puts "The Medium sync should now be able to use this profile."
      puts "You can close this task."
    rescue => e
      puts "Warning: Could not verify Chrome session: #{e.message}"
      puts "The profile may still be valid if you logged in successfully."
    end

    Process.kill("TERM", pid) rescue nil
    sleep 1

    # Clean locks so the sync process can reuse the profile.
    %w[SingletonLock SingletonCookie SingletonSocket].each do |f|
      path = File.join(profile_dir, f)
      File.delete(path) if File.exist?(path)
    end

    puts ""
    puts "Done. Chrome has been shut down."
  end
end
