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

    headless_server = ENV["DISPLAY"].to_s.empty? && !RbConfig::CONFIG["host_os"].include?("darwin")

    chrome_args = [
      "--remote-debugging-port=#{debug_port}",
      "--user-data-dir=#{profile_dir}",
      "--no-first-run",
      "--no-default-browser-check",
      "--window-size=1280,900",
      "--no-sandbox",
    ]

    # On a headless server, use xvfb-run to provide a virtual display so Chrome
    # runs in full headed mode. Cloudflare's Turnstile detects --headless=new,
    # but cannot distinguish a real display from a virtual framebuffer.
    if headless_server
      xvfb = `which xvfb-run 2>/dev/null`.strip
      if xvfb.empty?
        abort <<~MSG
          ERROR: xvfb-run is required on headless servers but was not found.
          Install it with:  sudo apt install xvfb
          Then re-run this task.
        MSG
      end
      spawn_args = [xvfb, "--auto-servernum", "--server-args=-screen 0 1280x900x24",
                    chrome_binary, *chrome_args, "https://medium.com"]
    else
      spawn_args = [chrome_binary, *chrome_args, "https://medium.com"]
    end

    puts ""
    puts "=" * 70
    puts "  Medium Sync — Interactive Login Setup"
    puts "=" * 70
    puts ""
    puts "Chrome is starting with the sync profile on debug port #{debug_port}."
    puts ""

    if headless_server
      puts "REMOTE SERVER DETECTED — using xvfb (virtual framebuffer)."
      puts ""
      puts "From your local machine, open an SSH tunnel (if not already open):"
      puts ""
      puts "  ssh -L #{debug_port}:127.0.0.1:#{debug_port} #{ENV['USER']}@<server-ip>"
      puts ""
      puts "Then, in your local Chrome browser, go to:"
      puts ""
      puts "  chrome://inspect/#devices"
      puts ""
      puts "Click 'Configure...' and add  localhost:#{debug_port}"
      puts "The remote medium.com page should appear under 'Remote Target'."
      puts "Click 'inspect' to get a live view you can interact with."
      puts "Log in to Medium with your account."
    else
      puts "A Chrome window should open. Log in to Medium with your account."
    end

    puts ""
    puts "Once logged in, come back here and press Enter to verify & save."
    puts "-" * 70
    puts ""

    pid = Process.spawn(*spawn_args, [:out, :err] => File::NULL)
    Process.detach(pid)

    # Wait for Chrome to start.
    sleep 3

    $stdin.gets

    # Verify login by checking cookies via CDP.
    require "net/http"
    require "json"

    begin
      # Check for the Medium uid cookie via CDP to verify actual login.
      pages_uri = URI("http://127.0.0.1:#{debug_port}/json")
      pages_res = Net::HTTP.get(pages_uri)
      pages = JSON.parse(pages_res)

      cookies_uri = URI("http://127.0.0.1:#{debug_port}/json/version")
      version_res = Net::HTTP.get(cookies_uri)
      version = JSON.parse(version_res)
      puts "Chrome version: #{version['Browser']}"

      # Read cookies from the page's cookie jar.
      page_title = pages.first&.dig("title") || ""
      page_url   = pages.first&.dig("url") || ""
      has_uid = false

      # Try to detect uid cookie via page title/URL heuristics.
      # A page on medium.com (not "Just a moment...") with a logged-in
      # indicator suggests success. For definitive verification we check
      # the Chrome profile's Cookies SQLite file.
      cookies_db = File.join(profile_dir, "Default", "Cookies")
      if File.exist?(cookies_db)
        require "open3"
        out, _ = Open3.capture2("sqlite3", cookies_db,
          "SELECT name FROM cookies WHERE host_key LIKE '%medium.com' AND name='uid' LIMIT 1;")
        has_uid = out.strip == "uid"
      end

      puts ""
      if has_uid
        puts "✓ Medium login verified (uid cookie found)."
        puts ""
        puts "Session cookies saved to the Chrome profile at:"
        puts "  #{profile_dir}"
        puts ""
        puts "The Medium sync should now work. You can close this task."
      else
        puts "⚠ WARNING: Medium 'uid' cookie NOT found."
        puts "  Current page: #{page_title} — #{page_url}"
        puts ""
        puts "  You may not have logged in yet. Re-run this task and use"
        puts "  chrome://inspect to interact with the remote browser."
      end
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
