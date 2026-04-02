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

      driver = build_driver
      begin
        inject_cookies(driver)
        sync_post(driver, edit_url, title, subtitle, content, post.url, link_label, config.footer_html.to_s)

        if is_new
          new_url = extract_medium_url(driver)
          append_medium_url_to_scratchpad(post, new_url) if new_url.present?
        end
      ensure
        driver.quit
      end
    end

    private

    def build_driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--disable-blink-features=AutomationControlled")
      options.logging_prefs = { browser: "ALL" }

      # Use a persistent Chrome profile so the Medium session (including Cloudflare
      # clearance) survives between runs without cookie injection. Cloudflare binds
      # cf_clearance to the browser's TLS fingerprint — re-injecting it into a fresh
      # Selenium session fails because the fingerprints differ even on the same machine.
      #
      # First-time setup (development): run with VISIBLE_BROWSER=1, log into Medium
      # when the browser opens, then let the sync complete. The profile is saved to
      # tmp/medium_sync_chrome_profile/ and reused automatically from then on.
      #
      # Production setup (one-time): SSH in and run:
      #   VISIBLE_BROWSER=1 RAILS_ENV=production bundle exec rails runner \
      #     "Medium::PostSyncer.execute(post_id: POST_ID)"
      # Log in when Chrome opens. After that, headless runs use the saved profile.
      profile_dir = Rails.root.join("tmp", "medium_sync_chrome_profile").to_s
      options.add_argument("--user-data-dir=#{profile_dir}")

      if headless?
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
      end

      driver = Selenium::WebDriver.for(:chrome, options: options)

      # Remove the webdriver property that sites use to detect automation
      driver.execute_cdp(
        "Page.addScriptToEvaluateOnNewDocument",
        source: "Object.defineProperty(navigator, 'webdriver', { get: () => undefined })"
      )

      driver
    end

    def headless?
      !Rails.env.development? && ENV["VISIBLE_BROWSER"].blank?
    end

    def inject_cookies(driver)
      cookies = Rails.application.credentials.medium[:cookies].map do |c|
        {
          name:     c[:name].to_s,
          value:    c[:value].to_s,
          domain:   c[:domain].to_s,
          path:     c[:path].to_s,
          secure:   true,
          sameSite: "None",
        }
      end
      driver.execute_cdp("Network.setCookies", cookies: cookies)
    end

    def sync_post(driver, edit_url, title, subtitle, content, post_url, link_label, footer_html)
      driver.navigate.to(edit_url)
      wait = Selenium::WebDriver::Wait.new(timeout: 30)

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

      # Pass 1: paste body content.
      # The range ends *before* p.graf--trailing so that element is preserved.
      # Medium requires the trailing paragraph to exist as a model constraint —
      # replacing it causes "Something is wrong and we cannot save your story."
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

        const dt = new DataTransfer();
        dt.setData('text/html', bodyHtml);
        dt.setData('text/plain', '');
        editable.dispatchEvent(new ClipboardEvent('paste', {
          bubbles: true,
          cancelable: true,
          clipboardData: dt
        }));
      JS

      # Give the body paste handler time to settle before the link paste.
      sleep 1

      # Pass 2: paste link content into (or after) the trailing paragraph.
      # Selecting the contents of trailingP and pasting replaces its text while
      # keeping the element itself in the model.
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
          // Replace only the contents of the existing trailing paragraph.
          range.selectNodeContents(trailingP);
        } else {
          // New post with no trailing paragraph: insert a new one at the end.
          range.selectNodeContents(inner);
          range.collapse(false);
        }
        sel.removeAllRanges();
        sel.addRange(range);

        const dt = new DataTransfer();
        dt.setData('text/html', trailingP ? linkHtml : '<p>' + linkHtml + '</p>');
        dt.setData('text/plain', '');
        editable.dispatchEvent(new ClipboardEvent('paste', {
          bubbles: true,
          cancelable: true,
          clipboardData: dt
        }));
      JS

      # Give the link paste handler time to settle before injecting the footer.
      sleep 2

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

      sleep 3
      capture_debug_info(driver)
    end

    def capture_debug_info(driver)
      ts   = Time.now.strftime("%Y%m%d_%H%M%S")
      base = Rails.root.join("tmp", "medium_sync_#{ts}")

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
