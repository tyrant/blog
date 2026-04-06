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

      medium_url = post.scratchpad.to_s.split("\r\n").find { |line| line.include?("medium.com") }.to_s
      is_new     = medium_url.blank?
      edit_url   = is_new ? "https://medium.com/new-story" : medium_edit_url(medium_url)

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
        establish_cloudflare_clearance(profile_dir)
        launch_chrome_process(profile_dir)
        wait_for_chrome_debug_port(SELF_LAUNCH_DEBUG_PORT)
        SELF_LAUNCH_DEBUG_PORT
      end

      options = Selenium::WebDriver::Chrome::Options.new(
        debugger_address: "127.0.0.1:#{port}"
      )
      options.logging_prefs = { browser: "ALL" }
      driver = Selenium::WebDriver.for(:chrome, options: options)

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

          // Timestamp updated each time /_/batch returns 200. Polled by Ruby
          // after the final paste to know when autosave has committed changes,
          // replacing the previous blind sleep 20.
          window.__mediumSyncLastBatchSuccessAt = 0;

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
              const isBatch  = url.includes('/_/batch');
              const isUpload = url.includes('/upload') || url.includes('/image');
              if (this.status >= 400) {
                console.error('[MediumSync XHR] ' + this.status + ' ' + url.split('?')[0] + ' | ' + (this.responseText || '').slice(0, 600));
              } else if (isBatch) {
                console.log('[MediumSync batch] ' + this.status + ' | ' + (this.responseText || '').slice(0, 800));
                if (this.status === 200) { window.__mediumSyncLastBatchSuccessAt = Date.now(); }
              } else if (isUpload) {
                console.log('[MediumSync upload] ' + this.status + ' ' + url.split('?')[0] + ' | ' + (this.responseText || '').slice(0, 400));
              }
            });
            return _xhrSend.apply(this, arguments);
          };

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
      # Skip Phase 1 if we obtained a fresh cf_clearance recently. Cloudflare's
      # clearance cookie is valid for ~30 minutes; using a 25-minute window gives
      # a 5-minute safety margin before Phase 2 would hit a challenge.
      stamp = Rails.root.join("tmp", "medium_sync_cf_cleared_at")
      if stamp.exist? && (Time.now - stamp.mtime) < 25.minutes
        Rails.logger.info("[MediumSync] CF clearance still valid (#{((Time.now - stamp.mtime) / 60).round}m old), skipping Phase 1")
        return
      end

      # Phase 1: launch Chrome without a remote-debugging port so that
      # navigator.webdriver is false and Cloudflare's Turnstile sees a real
      # browser. Navigate to medium.com to earn / renew cf_clearance, then
      # terminate Chrome so it commits the cookie to disk before Phase 2.
      #
      # On headless servers (production), --headless=new is added. The "new"
      # headless mode shares the same rendering engine as headed Chrome and is
      # very difficult for Cloudflare to fingerprint. Combined with no
      # --remote-debugging-port (so navigator.webdriver stays false), this
      # gives cf_clearance a strong chance of being granted.
      phase1_args = [
        chrome_binary_path,
        "--user-data-dir=#{profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=1280,900",
      ]
      if headless?
        phase1_args += %w[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu]
      end
      phase1_args << "https://medium.com"
      pid = Process.spawn(*phase1_args, [:out, :err] => File::NULL)
      Process.detach(pid)
      sleep 12  # allow medium.com to fully load and Cloudflare to set the cookie
      Process.kill("TERM", pid)
      sleep 1   # give Chrome time to flush cookies to disk
      clear_chrome_singleton_locks(profile_dir)
      stamp.write(Time.now.to_s)
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

      # Strip <img> tags from the body HTML and collect their bytes for separate
      # file-paste insertion after the subtitle (Medium's paste handler ignores
      # <img> tags in HTML pastes; only File ClipboardEvents create image blocks).
      content, images_for_paste = upload_images_for_medium(driver, content)

      # Pass 0: subtitle — ClipboardEvent paste targeting the subtitle paragraph so
      # Draft.js updates ContentState (direct innerHTML assignment is DOM-only).
      if subtitle.present?
        driver.execute_script(<<~JS, subtitle)
          const html      = arguments[0];
          const section1  = document.querySelector("section.section--first");
          const inner     = section1 && section1.querySelector(".section-inner");
          const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
          if (!inner || !editable) return;
          const titleEl   = inner.querySelector("h3[data-testid='editorTitleParagraph']");
          const trailingP = inner.querySelector("p.graf--trailing");
          const titleNext = titleEl && titleEl.nextElementSibling;
          // Accept trailingP as subtitle target for new stories where the trailing
          // paragraph doubles as the subtitle placeholder (no separate subtitle el yet).
          // After pasting, Medium auto-creates a fresh trailing paragraph.
          const subtitleEl = (titleNext && titleNext.tagName === "P") ? titleNext : null;
          console.log('[MediumSync] subtitle: el=' + !!subtitleEl
            + ' isTrailing=' + (subtitleEl === trailingP)
            + ' text="' + (subtitleEl ? subtitleEl.textContent.slice(0, 60) : 'n/a') + '"');
          if (!subtitleEl) return;

          const range = document.createRange();
          range.selectNodeContents(subtitleEl);
          const sel = window.getSelection();
          editable.focus();
          sel.removeAllRanges();
          sel.addRange(range);

          const dt = new DataTransfer();
          dt.setData('text/html', html.startsWith('<') ? html : '<p>' + html + '</p>');
          dt.setData('text/plain', html.replace(/<[^>]*>/g, ''));
          console.log('[MediumSync] dispatching subtitle paste');
          editable.dispatchEvent(new ClipboardEvent('paste', {
            clipboardData: dt, bubbles: true, cancelable: true, composed: true,
          }));
        JS
        sleep 0.5
      end

      # Pass 0b: images — skip if a figure already exists in the editor (re-sync
      # case). Dropping again would produce a duplicate image; the existing figure
      # is already in the right position and the body paste will anchor to it.
      existing_figure_count = driver.execute_script(
        "return document.querySelectorAll('figure[data-testid=\"editorImageParagraph\"]').length"
      )
      if existing_figure_count.zero?
        images_for_paste.each do |img_data|
          drop_image_into_editor(driver, img_data)
          insert_image_caption(driver, img_data[:caption])
        end
      end

      # Pass 1: body content.
      driver.execute_script(<<~JS, content)
        const html      = arguments[0];
        const section1  = document.querySelector("section.section--first");
        const inner     = section1 && section1.querySelector(".section-inner");
        const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
        if (!inner || !editable) { console.error('[MediumSync] editor not found'); return; }

        const titleEl   = inner.querySelector("h3[data-testid='editorTitleParagraph']");
        const trailingP = inner.querySelector("p.graf--trailing");
        const figure    = inner.querySelector("figure[data-testid='editorImageParagraph']");
        const titleNext  = titleEl && titleEl.nextElementSibling;
        // Accept trailingP as subtitleEl for new stories (same fix as subtitle pass).
        // After subtitle paste, Medium creates a fresh trailingP, so this will be
        // the filled subtitle paragraph, not the new empty trailing one.
        const subtitleEl = (titleNext && titleNext.tagName === "P") ? titleNext : null;

        // For a figure (atomic block), Draft.js prepends an empty block when the
        // range starts *after* the figure node — producing a blank line. Fix: always
        // start the range *inside* the first P after the figure so Draft.js treats
        // it as "replace this text block" rather than "insert after atomic block".
        // This applies whether the first P is a dedicated empty buffer or the trailingP.
        let rangeStart = figure || subtitleEl || titleEl;
        let fromInside = false;
        if (figure) {
          const afterFigure = figure.nextElementSibling;
          if (afterFigure && afterFigure.tagName === 'P') {
            rangeStart = afterFigure;
            fromInside = true;
          }
        }
        const range = document.createRange();
        const sel   = window.getSelection();
        editable.focus();
        if (fromInside) {
          range.setStart(rangeStart, 0);
        } else {
          range.setStartAfter(rangeStart);
        }
        // Always extend to the end of section-inner so that all existing body
        // paragraphs and the link paragraph from a previous sync are swept out.
        // The link paste (pass 2) unconditionally re-adds the link at the end.
        range.setEndAfter(inner.lastElementChild || rangeStart);
        console.log('[MediumSync] body anchor: ' + rangeStart.tagName + (fromInside ? ' (inside)' : ' (after)'));
        sel.removeAllRanges();
        sel.addRange(range);

        const dt = new DataTransfer();
        dt.setData('text/html', html);
        dt.setData('text/plain', html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());
        const pasteEvent = new ClipboardEvent('paste', {
          clipboardData: dt,
          bubbles: true,
          cancelable: true,
          composed: true,
        });
        console.log('[MediumSync] dispatching body paste, html length: ' + html.length);
        editable.dispatchEvent(pasteEvent);
        console.log('[MediumSync] body paste dispatched, defaultPrevented: ' + pasteEvent.defaultPrevented);
      JS

      sleep 0.5

      # Pass 2: link / trailing paragraph.
      driver.execute_script(<<~JS, post_url, link_label)
        const postUrl   = arguments[0];
        const linkLabel = arguments[1];
        const linkHtml  = '<p>' + linkLabel + ' <a href="' + postUrl + '">' + postUrl + '</a></p>';

        const section1  = document.querySelector("section.section--first");
        const inner     = section1 && section1.querySelector(".section-inner");
        const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
        if (!inner || !editable) { console.error('[MediumSync] editor not found for link pass'); return; }

        const lastBlock = inner && inner.lastElementChild;
        const range     = document.createRange();
        const sel       = window.getSelection();
        editable.focus();
        if (lastBlock) {
          range.selectNodeContents(lastBlock);
          range.collapse(false);
        } else {
          range.selectNodeContents(inner);
          range.collapse(false);
        }
        sel.removeAllRanges();
        sel.addRange(range);

        const dt = new DataTransfer();
        dt.setData('text/html', '<p></p>' + linkHtml);
        dt.setData('text/plain', linkLabel + ' ' + postUrl);
        console.log('[MediumSync] dispatching link paste');
        editable.dispatchEvent(new ClipboardEvent('paste', {
          clipboardData: dt, bubbles: true, cancelable: true, composed: true,
        }));
      JS

      sleep 0.5

      # Apply italic to the link paragraph via a trusted keyboard shortcut.
      # <em> in the HTML paste does not survive Medium's inline-style normalisation,
      # so we select the paragraph content and toggle italic with a real keystroke.
      # Draft.js uses metaKey (⌘) on macOS and ctrlKey on Linux for formatting.
      italic_modifier = RbConfig::CONFIG["host_os"].include?("darwin") ? :meta : :control
      begin
        editable_el = driver.find_element(css: ".postArticle-content[contenteditable='true']")
        driver.execute_script(<<~JS, editable_el)
          const editable  = arguments[0];
          const section1  = document.querySelector("section.section--first");
          const inner     = section1 && section1.querySelector(".section-inner");
          const trailingP = inner && inner.querySelector("p.graf--trailing");
          const linkP     = trailingP || (inner && inner.lastElementChild);
          console.log('[MediumSync] italic target: ' + (linkP ? linkP.tagName + ' text=' + linkP.textContent.slice(0, 40) : 'none'));
          if (!linkP || linkP.tagName !== 'P') return;
          const range = document.createRange();
          range.selectNodeContents(linkP);
          const sel = window.getSelection();
          editable.focus();
          sel.removeAllRanges();
          sel.addRange(range);
        JS
        editable_el.send_keys([italic_modifier, "i"])
        editable_el.send_keys(:end)
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      # Remove any footer content left over from a previous sync:
      # - Elements inside section-inner after the trailingP (appended by earlier syncs)
      # - Separate <section> elements after section--first (Medium's own footer sections)
      driver.execute_script(<<~JS)
        const section1  = document.querySelector("section.section--first");
        const inner     = section1 && section1.querySelector(".section-inner");
        const trailingP = inner && inner.querySelector("p.graf--trailing");
        if (inner && trailingP) {
          let el = trailingP.nextElementSibling;
          while (el) {
            const next = el.nextElementSibling;
            el.remove();
            el = next;
          }
        }
        document.querySelectorAll(".postArticle-content section:not(.section--first)").forEach(s => s.remove());
        const editable = document.querySelector(".postArticle-content[contenteditable='true']");
        if (editable) editable.dispatchEvent(new InputEvent('input', { bubbles: true }));
      JS

      # Pass 3: footer — ClipboardEvent paste after last block in section--first.
      #
      # Cursor must be positioned at the END OF THE LAST BLOCK (inside section-inner),
      # not at the end of the editable root. When the cursor is outside all blocks
      # (after section.section--first in the editable), Draft.js has no block context
      # and merges the pasted content into the preceding paragraph instead of creating
      # new blocks — producing the link+footer single-paragraph merge bug.
      if footer_html.present?
        driver.execute_script(<<~JS, footer_html)
          const html      = arguments[0];
          const editable  = document.querySelector(".postArticle-content[contenteditable='true']");
          const section1  = document.querySelector("section.section--first");
          const inner     = section1 && section1.querySelector(".section-inner");
          const lastBlock = inner && inner.lastElementChild;
          if (!editable || !lastBlock) { console.error('[MediumSync] footer: editor/lastBlock not found'); return; }

          // Cursor at end of last block content — Draft.js sees a proper block
          // boundary and inserts the pasted content as new blocks after this one.
          const range = document.createRange();
          range.selectNodeContents(lastBlock);
          range.collapse(false);
          const sel = window.getSelection();
          editable.focus();
          sel.removeAllRanges();
          sel.addRange(range);

          // Prepend an empty <p> so that Draft.js appends nothing to the last block
          // (the link paragraph) and starts the footer content in a new block.
          // Without this, Draft.js merges the first footer block into the link paragraph.
          const dt = new DataTransfer();
          dt.setData('text/html', '<p></p>' + html);
          dt.setData('text/plain', html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());
          console.log('[MediumSync] dispatching footer paste');
          editable.dispatchEvent(new ClipboardEvent('paste', {
            clipboardData: dt, bubbles: true, cancelable: true, composed: true,
          }));
        JS
        sleep 0.5
      end

      # Wait for Medium's autosave (/_/batch) to confirm all changes are saved,
      # rather than sleeping a fixed 20 seconds. The XHR monitor sets
      # window.__mediumSyncLastBatchSuccessAt whenever /_/batch returns 200;
      # we record a marker just before waiting and poll for a newer timestamp.
      # Falls back gracefully if no batch fires within 30 seconds.
      begin
        marker_ms = driver.execute_script("return Date.now()")
        Selenium::WebDriver::Wait.new(timeout: 30).until do
          driver.execute_script(
            "return (window.__mediumSyncLastBatchSuccessAt || 0) > arguments[0]",
            marker_ms
          )
        end
        Rails.logger.info("[MediumSync] autosave confirmed")
      rescue Selenium::WebDriver::Error::TimeoutError
        Rails.logger.warn("[MediumSync] autosave timeout: /_/batch success not detected within 30s, proceeding")
      end

      suppress_beforeunload_dialog(driver)
      capture_debug_info(driver)
    end

    # Prevent Medium's beforeunload confirm dialog from appearing when the
    # browser is closed after a sync. Medium registers a beforeunload handler
    # that checks an internal dirty flag; even after /_/batch returns 200, the
    # flag may still be set when driver.quit fires. We inject a capture-phase
    # listener that fires first, stops Medium's handler from running at all, and
    # clears returnValue — the three conditions Chrome requires to suppress the
    # dialog. Also nulls window.onbeforeunload as a belt-and-braces measure.
    def suppress_beforeunload_dialog(driver)
      driver.execute_script(<<~JS)
        window.onbeforeunload = null;
        window.addEventListener('beforeunload', function(e) {
          e.stopImmediatePropagation();
          delete e.returnValue;
        }, { capture: true });
      JS
      Rails.logger.info("[MediumSync] beforeunload suppressed")
    rescue => e
      Rails.logger.warn("[MediumSync] suppress_beforeunload_dialog: #{e.message}")
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

    # Strip <img> tags from +html+, download each image's bytes, and return
    # [stripped_html, [{body:, content_type:, caption:}, ...]]. The caller drops
    # image data via CDP DragEvent so Medium's upload handler fires, then inserts
    # any caption into the figure's caption input.
    #
    # Caption extraction: if a plain <p> immediately follows the image's parent
    # block it is treated as the image caption — removed from the body HTML and
    # included as :caption in the image hash so the caller can paste it into
    # Medium's caption field. A heading, media element, or multi-element block
    # is not eligible and stays in the body.
    def upload_images_for_medium(driver, html)
      doc = Nokogiri::HTML.fragment(html)
      imgs = doc.css("img[src]")
      driver.execute_script(
        "console.log('[MediumSync] images: ' + arguments[0])",
        imgs.map { |i| i["src"].to_s }.join(", ")
      )
      return [html, []] if imgs.empty?

      images_for_paste = []

      imgs.each do |img|
        src    = img["src"].to_s
        parent = img.parent

        # Check for a caption candidate BEFORE removing the img, so we can
        # inspect what other content the parent block contains.
        caption = nil
        if parent && parent.element? &&
            %w[p h1 h2 h3 h4 blockquote li pre].include?(parent.name)
          # Only consider a caption when the img is the sole real content in
          # its parent (no other elements or non-whitespace text alongside it).
          other_content = parent.children.reject { |c| c == img || (c.text? && c.text.strip.empty?) }
          if other_content.empty?
            next_el = parent.next_element
            if next_el &&
                next_el.name == "p" &&
                next_el.text.strip.present? &&
                next_el.css("img, figure, video, audio, iframe").empty?
              caption = next_el.inner_html.strip
              next_el.remove
            end
          end
        end

        img.remove
        # If removing the img left its parent block completely empty, remove the
        # parent too — otherwise it pastes as a blank line before the body text.
        if parent && parent.element? &&
            %w[p h1 h2 h3 h4 blockquote li pre].include?(parent.name) &&
            parent.children.all? { |c| c.text? && c.text.strip.empty? }
          parent.remove
        end
        next if src.blank? || src.start_with?("data:")

        unless src.start_with?("http", "//")
          src = "#{Rails.application.routes.url_helpers.root_url.chomp('/')}#{src}"
        end

        data = download_image_bytes(src)
        images_for_paste << data.merge(caption: caption) if data
      end

      [doc.to_html, images_for_paste]
    end

    # Drop +img_data+ ({body:, content_type:}) into the editor using CDP
    # Input.dispatchDragEvent with the image written to a temp file. CDP creates
    # a real DataTransfer with a real File object — bypassing Chrome's security
    # restriction that prevents synthetic ClipboardEvents from carrying files.
    # Medium's drop handler then calls /_/upload and inserts the figure block.
    def drop_image_into_editor(driver, img_data)
      require "tempfile"
      mime_type = img_data[:content_type]
      ext       = (mime_type.split("/").last || "jpg").gsub("jpeg", "jpg")

      temp = Tempfile.new(["medium_sync_image", ".#{ext}"])
      temp.binmode
      temp.write(img_data[:body])
      temp.flush
      temp.close

      before_count = driver.execute_script(
        "return document.querySelectorAll('figure[data-testid=\"editorImageParagraph\"]').length"
      )

      # Get drop coordinates: just below the subtitle (or title) element.
      drop_coords = driver.execute_script(<<~JS)
        var section1  = document.querySelector('section.section--first');
        var inner     = section1 && section1.querySelector('.section-inner');
        var titleEl   = inner && inner.querySelector('h3[data-testid="editorTitleParagraph"]');
        var titleNext = titleEl && titleEl.nextElementSibling;
        var subtitleEl = (titleNext && titleNext.tagName === 'P') ? titleNext : null;
        var anchorEl  = subtitleEl || titleEl;
        if (!anchorEl) return null;
        var r = anchorEl.getBoundingClientRect();
        return { x: Math.round(r.left + r.width / 2), y: Math.round(r.bottom + 10) };
      JS

      if drop_coords.nil?
        Rails.logger.warn("[MediumSync] drop_image_into_editor: anchor element not found")
        return
      end

      x = drop_coords["x"].to_f
      y = drop_coords["y"].to_f
      drag_data = {
        items:              [{ mimeType: mime_type, data: "" }],
        files:              [temp.path],
        dragOperationsMask: 1,
      }

      driver.execute_script("console.log('[MediumSync] image drop at ' + #{x.to_i} + ',' + #{y.to_i})")
      driver.execute_cdp("Input.dispatchDragEvent", type: "dragEnter", x: x, y: y, data: drag_data)
      sleep 0.1
      driver.execute_cdp("Input.dispatchDragEvent", type: "dragOver",  x: x, y: y, data: drag_data)
      sleep 0.1
      driver.execute_cdp("Input.dispatchDragEvent", type: "drop",      x: x, y: y, data: drag_data)
      driver.execute_script("console.log('[MediumSync] image drop dispatched')")

      begin
        Selenium::WebDriver::Wait.new(timeout: 45).until do
          driver.execute_script(
            "return document.querySelectorAll('figure[data-testid=\"editorImageParagraph\"]').length"
          ) > before_count
        end
        driver.execute_script("console.log('[MediumSync] image figure appeared')")
      rescue Selenium::WebDriver::Error::TimeoutError
        driver.execute_script("console.error('[MediumSync] image figure did not appear after drop')")
      end
    rescue => e
      Rails.logger.warn("[MediumSync] drop_image_into_editor failed: #{e.message}")
    ensure
      temp&.unlink rescue nil
    end

    # After dropping an image, click the figure to trigger Medium's caption UI,
    # then paste +caption+ (inner HTML of the source paragraph) into the figcaption.
    # No-ops silently when caption is blank or the figcaption doesn't appear
    # (e.g. Medium changes the DOM) so the rest of the sync is unaffected.
    def insert_image_caption(driver, caption)
      return if caption.blank?

      begin
        # The most recently dropped figure is always last in document order.
        figures = driver.find_elements(css: "figure[data-testid='editorImageParagraph']")
        return if figures.empty?

        figure = figures.last
        driver.execute_script("arguments[0].scrollIntoView({block: 'center'})", figure)
        sleep 0.2
        figure.click
        sleep 0.3

        # Medium renders a <figcaption> inside the figure once it's selected.
        caption_el = Selenium::WebDriver::Wait.new(timeout: 5).until do
          els = driver.find_elements(css: "figure[data-testid='editorImageParagraph'] figcaption")
          els.last if els.any?
        end

        # Paste via ClipboardEvent so Draft.js updates ContentState, not just the DOM.
        driver.execute_script(<<~JS, caption_el, caption)
          const captionEl = arguments[0];
          const html      = arguments[1];
          captionEl.focus();
          const range = document.createRange();
          range.selectNodeContents(captionEl);
          const sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);
          const dt = new DataTransfer();
          dt.setData('text/html', html.startsWith('<') ? html : '<p>' + html + '</p>');
          dt.setData('text/plain', html.replace(/<[^>]*>/g, ''));
          captionEl.dispatchEvent(new ClipboardEvent('paste', {
            clipboardData: dt, bubbles: true, cancelable: true, composed: true,
          }));
        JS
        driver.execute_script(
          "console.log('[MediumSync] caption inserted: ' + arguments[0].slice(0, 60))",
          caption.gsub(/<[^>]*>/, "").slice(0, 60)
        )
      rescue Selenium::WebDriver::Error::TimeoutError,
             Selenium::WebDriver::Error::NoSuchElementError => e
        Rails.logger.warn("[MediumSync] insert_image_caption: #{e.message}")
      end
    end

    def download_image_bytes(url, redirect_limit: 5)
      # Fast path: read local ActiveStorage blobs directly from storage rather than
      # making an HTTP round-trip back to the same Puma process (which can deadlock
      # when the job runs in-process on the async adapter).
      if (match = url.match(%r{/rails/active_storage/blobs/(?:redirect|inline)/([^/]+)/}))
        begin
          blob = ActiveStorage::Blob.find_signed!(match[1])
          return { body: blob.download, content_type: blob.content_type || "image/jpeg" }
        rescue => e
          raise "ActiveStorage blob read failed (#{e.class}): #{e.message}"
        end
      end

      require "net/http"
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: 10, read_timeout: 30) do |http|
        response = http.get(uri.request_uri)
        case response
        when Net::HTTPSuccess
          content_type = response["content-type"]&.split(";")&.first&.strip || "image/jpeg"
          { body: response.body, content_type: content_type }
        when Net::HTTPRedirection
          raise "Too many redirects" if redirect_limit.zero?
          download_image_bytes(response["location"], redirect_limit: redirect_limit - 1)
        else
          Rails.logger.warn("[MediumSync] image download got #{response.code} for #{url}")
          nil
        end
      end
    rescue => e
      Rails.logger.warn("[MediumSync] image download failed for #{url}: #{e.message}")
      nil
    end

    def set_field(driver, element, text)
      # Cmd+A on macOS, Ctrl+A on Linux — Ctrl+A in a Mac browser moves the
      # cursor to start-of-line rather than selecting all content.
      select_all = RbConfig::CONFIG["host_os"].include?("darwin") ? :meta : :control
      element.click
      element.send_keys([select_all, "a"])
      element.send_keys(text)
    end

    def extract_medium_url(driver)
      wait = Selenium::WebDriver::Wait.new(timeout: 20)
      wait.until do
        url = driver.current_url
        url&.include?("medium.com") && !url.end_with?("/new-story")
      end
      driver.current_url
    rescue Selenium::WebDriver::Error::TimeoutError,
           Selenium::WebDriver::Error::WebDriverError
      nil
    end

    # Derive the Medium editor URL from any Medium URL format:
    #   medium.com/p/HASH/edit       → already correct, return as-is
    #   mikey-clarke.medium.com/HASH → unpublished show URL
    #   medium.com/@user/slug-HASH   → published show URL
    # All formats contain a 12-char hex post ID; construct medium.com/p/HASH/edit.
    def medium_edit_url(url)
      return url if url.match?(%r{medium\.com/p/[a-f0-9]+/edit$}i)

      hash = url.match(%r{(?:/p/|[-/])([a-f0-9]{12})(?:/edit)?/?$}i)&.[](1)
      hash ? "https://medium.com/p/#{hash}/edit" : "#{url.chomp("/edit")}/edit"
    end

    def append_medium_url_to_scratchpad(post, url)
      parts = [post.scratchpad.to_s.rstrip, url].reject(&:empty?)
      post.update!(scratchpad: parts.join("\r\n\r\n"))
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
    KEEP_ATTRS = %w[href target rel src alt].freeze

    # Elements with no Medium equivalent that must be removed entirely.
    # img/picture are handled separately: upload_images_for_medium replaces
    # external src URLs with Medium CDN URLs before pasting. picture is unwrapped
    # to expose its img child.
    REMOVE_TAGS = %w[video audio iframe script style svg canvas
                     form input button select textarea source].freeze

    # Generic container elements with no Medium block equivalent.
    # We unwrap these (keeping their children) rather than deleting them,
    # so their text content is preserved. picture is unwrapped to expose
    # its img child (source/srcset elements are removed in REMOVE_TAGS).
    UNWRAP_TAGS = %w[div figure figcaption section article header footer
                     aside nav main span picture].freeze

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
