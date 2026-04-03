# frozen_string_literal: true

module Medium
  class PostSyncer
    include ServiceInterface

    arguments :post_id

    def execute
      post   = Comfy::Blog::Post.find(@post_id)
      config = MediumSyncConfig.instance

      title      = config.title_template.gsub("{{title}}", post.title)
      content    = normalize_for_medium(config.content_template.gsub("{{content}}", post.content_cache.to_s))
      subtitle   = config.subtitle.to_s
      link_label = config.link_template.gsub("{{url}}", "").strip

      medium_url = post.socials_url_for(platform: "medium")
      is_new     = medium_url.blank?
      edit_url   = is_new ? "https://medium.com/new-story" : "#{medium_url.sub(%r{/edit$}, "")}/edit"

      @attached_chrome = chrome_debug_port_open?
      driver = build_driver
      begin
        sync_post(driver, edit_url, title, subtitle, content, post.url, link_label, config.footer_html.to_s)

        if is_new
          new_url = extract_medium_url(driver)
          append_medium_url_to_scratchpad(post, new_url) if new_url.present?
        end
      ensure
        driver&.quit rescue nil
        # Kill the Chrome process we launched ourselves (not the user's pre-running Chrome).
        Process.kill("TERM", @launched_chrome_pid) rescue nil if @launched_chrome_pid
      end
    end

    private

    # Port used when the user has pre-launched Chrome with --remote-debugging-port=9222.
    CHROME_REMOTE_DEBUG_PORT = 9222
    # Port used when Rails launches Chrome itself (avoids conflicts with the user's Chrome).
    SELF_LAUNCH_DEBUG_PORT   = 9223

    def chrome_debug_port_open?
      require "net/http"
      uri = URI("http://127.0.0.1:#{CHROME_REMOTE_DEBUG_PORT}/json/version")
      res = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 2) do |http|
        http.get(uri.path)
      end
      res.is_a?(Net::HTTPSuccess)
    rescue Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET
      false
    end

    def build_driver
      port = if @attached_chrome
        CHROME_REMOTE_DEBUG_PORT
      else
        # Two-phase launch to work around Cloudflare's Turnstile bot detection:
        #
        # Phase 1 — launch Chrome WITHOUT --remote-debugging-port so that
        # navigator.webdriver is false. Turnstile sees a real browser, so it
        # issues (or renews) a cf_clearance cookie stored in the sync profile.
        # Chrome is killed after the page loads.
        #
        # Phase 2 — relaunch Chrome WITH --remote-debugging-port so ChromeDriver
        # can attach. We navigate directly to the editor URL, skipping medium.com
        # entirely, so Turnstile never runs again and cf_clearance stays valid.
        profile_dir = Rails.root.join("tmp", "medium_sync_chrome_profile")
        clear_chrome_singleton_locks(profile_dir)
        establish_cloudflare_clearance(profile_dir) unless headless?
        launch_chrome_process(profile_dir)
        wait_for_chrome_debug_port(SELF_LAUNCH_DEBUG_PORT)
        SELF_LAUNCH_DEBUG_PORT
      end

      options = Selenium::WebDriver::Chrome::Options.new(
        debugger_address: "127.0.0.1:#{port}"
      )
      options.logging_prefs = { browser: "ALL" }
      driver = Selenium::WebDriver.for(:chrome, options: options)

      # Grant clipboard read/write permission so we can set HTML clipboard content
      # via navigator.clipboard.write() for trusted paste events.
      driver.execute_cdp("Browser.grantPermissions", {
        "permissions" => ["clipboardReadWrite"],
        "origin"      => "https://medium.com"
      })

      # Log failed Medium API calls to the browser console so capture_debug_info
      # can surface the exact backend error message.
      driver.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        (function() {
          // Hide the WebDriver flag so Cloudflare's challenge can be solved.
          // Chrome launched without --enable-automation is already clean; the
          // only remaining automation signal is navigator.webdriver being set
          // by ChromeDriver's attachment. Overriding it here (before any page
          // script runs) prevents Cloudflare from looping on the CAPTCHA.
          Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
            configurable: true
          });

          console.log('[MediumSync] monitor active');

          // Wrap fetch to capture failed Medium API calls.
          const _fetch = window.fetch;
          window.fetch = async function(...args) {
            const res = await _fetch(...args);
            if (!res.ok && String(args[0]).includes('medium.com')) {
              const body = await res.clone().text().catch(() => '');
              console.error('[MediumSync fetch] ' + res.status + ' ' + String(args[0]).split('?')[0] + ' | ' + body.slice(0, 600));
            }
            return res;
          };

          // Wrap XHR — Medium's editor uses XHR for /_/batch and other API calls.
          // Medium uses relative URLs (e.g. "/_/batch"), so we match on those too.
          const _xhrOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            this._msUrl = String(url);
            return _xhrOpen.apply(this, arguments);
          };
          const _xhrSend = XMLHttpRequest.prototype.send;
          XMLHttpRequest.prototype.send = function() {
            this.addEventListener('load', function() {
              const url = this._msUrl || '';
              const isMedium = url.includes('medium.com') || url.startsWith('/');
              if (!isMedium) return;
              const isBatch = url.includes('/_/batch');
              if (this.status >= 400) {
                console.error('[MediumSync XHR] ' + this.status + ' ' + url.split('?')[0] + ' | ' + (this.responseText || '').slice(0, 600));
              } else if (isBatch) {
                console.log('[MediumSync batch] ' + this.status + ' | ' + (this.responseText || '').slice(0, 800));
              }
            });
            return _xhrSend.apply(this, arguments);
          };

          // Clipboard writer triggered by CDP F13 keydown.
          // A CDP-dispatched keydown has isTrusted:true, satisfying Chrome's
          // user-activation requirement for navigator.clipboard.write().
          // Ruby sets window.__mediumSyncHtmlToPaste before firing F13, then
          // polls window.__clipboardReady until it becomes true.
          document.addEventListener('keydown', function(e) {
            if (e.key !== 'F13' || !window.__mediumSyncHtmlToPaste) return;
            navigator.clipboard.write([
              new ClipboardItem({ 'text/html': new Blob([window.__mediumSyncHtmlToPaste], { type: 'text/html' }) })
            ]).then(function() {
              window.__clipboardReady = true;
            }).catch(function(err) {
              window.__clipboardReady = 'err:' + String(err);
            });
          });
        })();
      JS

      driver
    end

    def launch_chrome_process(profile_dir)
      args = [
        chrome_binary_path,
        "--remote-debugging-port=#{SELF_LAUNCH_DEBUG_PORT}",
        "--user-data-dir=#{profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
      ]
      if headless?
        args += %w[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu]
      else
        args << "--window-size=1280,900"
      end
      @launched_chrome_pid = Process.spawn(*args, [:out, :err] => File::NULL)
      Process.detach(@launched_chrome_pid)
    end

    def wait_for_chrome_debug_port(port, timeout: 20)
      require "socket"
      deadline = Time.now + timeout
      loop do
        TCPSocket.new("127.0.0.1", port).close
        return
      rescue Errno::ECONNREFUSED
        raise Selenium::WebDriver::Error::WebDriverError, "Chrome did not start on port #{port} within #{timeout}s" if Time.now > deadline
        sleep 0.3
      end
    end

    def chrome_binary_path
      ENV["CHROME_BINARY"].presence ||
        [
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          "/usr/bin/google-chrome",
          "/usr/bin/google-chrome-stable",
          "/usr/bin/chromium-browser",
          "/usr/bin/chromium",
        ].find { |p| File.executable?(p) } ||
        raise(Selenium::WebDriver::Error::WebDriverError, "Chrome binary not found; set CHROME_BINARY env var")
    end

    def wait_for_cloudflare_clearance(driver)
      # Wait until Cloudflare's challenge elements are gone and the page is fully loaded.
      # Allows up to 90 seconds so the user can solve a CAPTCHA if one appears.
      Selenium::WebDriver::Wait.new(timeout: 90).until do
        driver.execute_script(
          "return document.readyState === 'complete' && " \
          "!document.querySelector('#cf-challenge-running, #challenge-form, #turnstile-wrapper')"
        )
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end

    def wait_for_medium_login(driver)
      # Wait until the Medium session cookie appears. Medium sets a `uid` cookie
      # on successful login; its presence is a reliable logged-in indicator.
      # Uses driver.manage.all_cookies (not document.cookie) so httpOnly cookies
      # are visible. Allows up to 120 seconds for first-time login setup.
      Selenium::WebDriver::Wait.new(timeout: 120).until do
        driver.manage.all_cookies.any? { |c| c[:name] == "uid" }
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end

    def establish_cloudflare_clearance(profile_dir)
      # Phase 1: launch Chrome without a remote-debugging port so that
      # navigator.webdriver is false and Cloudflare's Turnstile sees a real
      # browser. Navigate to medium.com to earn / renew cf_clearance, then
      # terminate Chrome so it commits the cookie to disk before Phase 2.
      pid = Process.spawn(
        chrome_binary_path,
        "--user-data-dir=#{profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=1280,900",
        "https://medium.com",
        [:out, :err] => File::NULL
      )
      Process.detach(pid)
      sleep 12  # allow medium.com to fully load and Cloudflare to set the cookie
      Process.kill("TERM", pid)
      sleep 1   # give Chrome time to flush cookies to disk
      clear_chrome_singleton_locks(profile_dir)
    rescue => e
      Rails.logger.warn("[MediumSync] CF clearance phase-1 failed: #{e.message}")
    end

    def clear_chrome_singleton_locks(profile_dir)
      %w[SingletonLock SingletonCookie SingletonSocket].each do |f|
        path = profile_dir.join(f)
        File.delete(path) if path.exist?
      end
    end

    def headless?
      !Rails.env.development? && ENV["VISIBLE_BROWSER"].blank?
    end


    def sync_post(driver, edit_url, title, subtitle, content, post_url, link_label, footer_html)
      # Visit medium.com first to establish/refresh the Cloudflare session before
      # hitting the editor. cf_clearance is copied fresh from the user's real Chrome
      # profile on each run, so this load should pass without a challenge.
      # Phase 2: go straight to the editor — never visit medium.com's homepage.
      # cf_clearance was established in Phase 1 (no WebDriver). Navigating to
      # medium.com here would run Turnstile again (with navigator.webdriver=true)
      # and revoke the clearance, causing a CAPTCHA loop on the next run.
      driver.navigate.to(edit_url)
      wait_for_cloudflare_clearance(driver)
      wait = Selenium::WebDriver::Wait.new(timeout: 60)

      title_el = wait.until { driver.find_element(css: "h3[data-testid='editorTitleParagraph']") }
      set_field(driver, title_el, title)

      # Fire a real trusted keystroke in the body to set Medium's internal
      # "user has started editing" flag. Synthetic paste events alone don't
      # trigger this flag, so without it autosave won't run and Publish stays
      # disabled regardless of how much content is in the editor model.
      # Re-query the element inside the retry loop: the title send_keys causes
      # Medium to re-render, which stales any reference taken before that point.
      begin
        Selenium::WebDriver::Wait.new(timeout: 5).until do
          el = driver.find_element(css: "section.section--first p[data-testid='editorParagraphText']")
          el.click
          el.send_keys(" ")
          el.send_keys(:backspace)
          true
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
          false
        end
      rescue Selenium::WebDriver::Error::TimeoutError,
             Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      # Pass 1: paste body content via trusted clipboard (navigator.clipboard.write + CDP keyDown).
      # Synthetic ClipboardEvent with isTrusted:false updates the DOM but not Draft.js state,
      # causing autosave to serialise title-only content. navigator.clipboard.write() produces
      # a trusted paste event that Draft.js recognises.
      #
      # Step A: set subtitle if blank, then select the body range (no paste yet).
      driver.execute_script(<<~JS, subtitle, content)
        const subtitleHtml = arguments[0];
        const bodyHtml     = arguments[1];

        const section1  = document.querySelector("section.section--first");
        const inner     = section1 && section1.querySelector(".section-inner");
        const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
        if (!inner || !editable) return;

        const titleEl   = inner.querySelector("h3[data-testid='editorTitleParagraph']");
        const trailingP = inner.querySelector("p.graf--trailing");
        const figure    = inner.querySelector("figure[data-testid='editorImageParagraph']");

        // Subtitle: first sibling after title that is a P but not the trailing link paragraph.
        const titleNext  = titleEl && titleEl.nextElementSibling;
        const subtitleEl = (titleNext && titleNext.tagName === "P" && titleNext !== trailingP)
          ? titleNext : null;

        // Set subtitle via innerHTML — only when currently blank.
        if (subtitleHtml.trim() && subtitleEl && !subtitleEl.textContent.trim()) {
          subtitleEl.innerHTML = subtitleHtml;
        }

        // Content anchor: figure > subtitle > title.
        const contentAnchor = figure || subtitleEl || titleEl;

        const range = document.createRange();
        const sel   = window.getSelection();
        editable.focus();
        range.setStartAfter(contentAnchor);
        // End before trailingP (preserving it) or at the last element if none exists.
        if (trailingP) {
          range.setEndBefore(trailingP);
        } else {
          range.setEndAfter(inner.lastElementChild || contentAnchor);
        }
        sel.removeAllRanges();
        sel.addRange(range);

        // Store HTML on window for the async clipboard write below.
        window.__mediumSyncBodyHtml = bodyHtml;
      JS

      # Step B: write to the real clipboard asynchronously.
      driver.execute_async_script(<<~JS)
        const done = arguments[arguments.length - 1];
        const html = window.__mediumSyncBodyHtml || '';
        navigator.clipboard.write([
          new ClipboardItem({ 'text/html': new Blob([html], { type: 'text/html' }) })
        ]).then(() => done('ok')).catch(e => done('err:' + e));
      JS

      # Step C: send trusted Cmd+V (Mac) / Ctrl+V (Linux) via CDP to trigger the paste.
      # CDP modifier bit field: Alt=1, Ctrl=2, Meta/Cmd=4, Shift=8.
      paste_modifier = RUBY_PLATFORM.include?("darwin") ? 4 : 2
      driver.execute_cdp("Input.dispatchKeyEvent", {
        "type"      => "keyDown",
        "key"       => "v",
        "modifiers" => paste_modifier
      })
      driver.execute_cdp("Input.dispatchKeyEvent", {
        "type"      => "keyUp",
        "key"       => "v",
        "modifiers" => paste_modifier
      })

      # Give Draft.js time to process the paste before the link paste.
      sleep 2

      # Pass 2: paste link content into (or after) the trailing paragraph.
      # Same three-step approach: select → clipboard.write → CDP keyDown.
      #
      # Step A: select the trailing paragraph contents.
      driver.execute_script(<<~JS, post_url, link_label)
        const postUrl   = arguments[0];
        const linkLabel = arguments[1];

        const section1  = document.querySelector("section.section--first");
        const inner     = section1 && section1.querySelector(".section-inner");
        const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
        if (!inner || !editable) return;

        const trailingP = inner.querySelector("p.graf--trailing");
        const linkHtml  = linkLabel + '<a href="' + postUrl + '">' + postUrl + '</a>';
        const range     = document.createRange();
        const sel       = window.getSelection();
        editable.focus();

        if (trailingP) {
          range.selectNodeContents(trailingP);
        } else {
          range.selectNodeContents(inner);
          range.collapse(false);
        }
        sel.removeAllRanges();
        sel.addRange(range);

        window.__mediumSyncLinkHtml = trailingP ? linkHtml : '<p>' + linkHtml + '</p>';
      JS

      # Step B: write link HTML to clipboard.
      driver.execute_async_script(<<~JS)
        const done = arguments[arguments.length - 1];
        const html = window.__mediumSyncLinkHtml || '';
        navigator.clipboard.write([
          new ClipboardItem({ 'text/html': new Blob([html], { type: 'text/html' }) })
        ]).then(() => done('ok')).catch(e => done('err:' + e));
      JS

      # Step C: trusted paste keystroke.
      driver.execute_cdp("Input.dispatchKeyEvent", {
        "type"      => "keyDown",
        "key"       => "v",
        "modifiers" => paste_modifier
      })
      driver.execute_cdp("Input.dispatchKeyEvent", {
        "type"      => "keyUp",
        "key"       => "v",
        "modifiers" => paste_modifier
      })

      # Give the link paste handler time to settle before injecting the footer.
      sleep 2

      # Fire a trusted keystroke (End key — moves cursor, doesn't change content)
      # after all pastes so Medium's autosave debounce treats the model as dirty
      # and schedules a save.
      begin
        editable = driver.find_element(css: ".postArticle-content[contenteditable='true']")
        editable.click
        editable.send_keys(:end)
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      if footer_html.present?
        driver.execute_script(<<~JS, footer_html)
          const footerHtml = arguments[0];
          const editable   = document.querySelector(".postArticle-content[contenteditable='true']");
          if (!editable) return;

          // Footer sections are Medium's publication CTAs — server-generated display elements
          // that live outside the editor model. They must NOT go through the paste handler,
          // which would convert them into story content and cause the backend to reject the save.
          // Direct DOM insertion is correct here: they appear visually but are not serialised
          // by Medium's editor when it saves.
          document.querySelectorAll(".postArticle-content section:not(.section--first)")
            .forEach(function(s) { s.remove(); });
          editable.insertAdjacentHTML("beforeend", footerHtml);
        JS
      end

      sleep 20
      capture_debug_info(driver)
    end

    def capture_debug_info(driver)
      ts   = Time.now.strftime("%Y%m%d_%H%M%S")
      base = Rails.root.join("tmp", "medium_sync_#{ts}")

      Rails.logger.info("[MediumSync] URL at capture: #{driver.current_url}")
      driver.save_screenshot("#{base}.png")

      logs = driver.logs.get(:browser)
      File.write(
        "#{base}.log",
        logs.map { |e| "[#{e.level}] #{e.message}" }.join("\n")
      )
    rescue => e
      Rails.logger.warn("[MediumSync] debug capture failed: #{e.message}")
    end

    def set_field(driver, element, text)
      element.click
      element.send_keys([:control, "a"])
      element.send_keys(text)
    end

    def extract_medium_url(driver)
      wait = Selenium::WebDriver::Wait.new(timeout: 20)
      wait.until do
        url = driver.current_url
        url&.include?("medium.com") && !url.end_with?("/new-story")
      end
      driver.current_url&.sub(%r{/edit$}, "")
    rescue Selenium::WebDriver::Error::TimeoutError,
           Selenium::WebDriver::Error::WebDriverError
      nil
    end

    def append_medium_url_to_scratchpad(post, url)
      parts = [post.scratchpad.to_s.rstrip, url].reject(&:empty?)
      post.update!(scratchpad: parts.join("\r\n"))
    end

    # Normalise blog HTML for Medium's paste handler and backend serialiser.
    MEDIUM_GRAF_CLASSES = {
      "p"          => "graf graf--p",
      "h1"         => "graf graf--h2",
      "h2"         => "graf graf--h2",
      "h3"         => "graf graf--h3",
      "h4"         => "graf graf--h4",
      "blockquote" => "graf graf--blockquote",
      "ul"         => "graf graf--ul",
      "ol"         => "graf graf--ol",
      "li"         => "graf graf--li",
      "pre"        => "graf graf--pre",
    }.freeze

    # Attributes that carry semantic meaning and should survive normalisation.
    KEEP_ATTRS = %w[href target rel].freeze

    # Elements with no Medium equivalent that must be removed entirely.
    # img is included because Medium requires images on its own CDN — external
    # src URLs cause the backend to reject the save with "Something is wrong".
    REMOVE_TAGS = %w[img picture video audio iframe script style svg canvas
                     form input button select textarea].freeze

    # Generic container elements with no Medium block equivalent.
    # We unwrap these (keeping their children) rather than deleting them,
    # so their text content is preserved.
    UNWRAP_TAGS = %w[div figure figcaption section article header footer
                     aside nav main span].freeze

    def normalize_for_medium(html)
      doc = Nokogiri::HTML.fragment(html)

      doc.css(REMOVE_TAGS.join(", ")).remove

      # Unwrap container elements in repeated passes until none remain.
      # Multiple passes handle nesting: inner wrappers are exposed by the
      # outer unwrap and then removed in the next pass.
      5.times do
        nodes = doc.css(UNWRAP_TAGS.join(", "))
        break if nodes.empty?
        nodes.each { |node| node.replace(node.children) }
      end

      doc.traverse do |node|
        next unless node.element?
        node.attributes.each_key do |attr|
          node.remove_attribute(attr) unless KEEP_ATTRS.include?(attr)
        end
        if (graf_class = MEDIUM_GRAF_CLASSES[node.name])
          node["class"] = graf_class
        end
      end

      doc.to_html
    end
  end
end
