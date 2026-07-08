# Capping headless Chromium on prod

On 2026-07-08 the droplet was taken down by resource exhaustion: leaked headless
Chromium processes from browser automation in `/home/noob/scripts/`
(`playwright_profile`, `medium_playwright_profile`) accumulated, and on a 1.9 GB,
**zero-swap** box the load hit ~25 and RAM dropped to ~20 MB free — Passenger
couldn't serve, and even SSH refused connections.

The Rails Medium sync (`app/services/medium/post_syncer.rb`) already tears its
browser down, and was hardened to a **process-group** kill (commit — reaps the
xvfb-run/Xvfb/renderer tree, not just the parent). The pile-up came from the
standalone `/home/noob/scripts/*.py` Playwright jobs, which live on the server, not
in this repo. Cap them with the layers below (cheapest/highest-leverage first).

Do these **after the box is back up** (and after adding swap — see
[the swap steps](#swap)).

## 1. Reaper cron (backstop)

Kills automation Chrome older than N minutes, by process group. See
[`ops/reap-stale-chrome.sh`](../ops/reap-stale-chrome.sh).

```bash
mkdir -p ~/bin ~/log
cp ops/reap-stale-chrome.sh ~/bin/ && chmod +x ~/bin/reap-stale-chrome.sh
crontab -e
# */5 * * * * /home/noob/bin/reap-stale-chrome.sh 10 >> /home/noob/log/chrome-reaper.log 2>&1
```

Adjust the `PATTERN` in the script to match the actual profile names your scripts use.

## 2. flock — no overlapping runs

A slow/hung run must not stack with the next scheduled one. Wrap each browser cron
job so concurrency stays at 1:

```cron
*/30 * * * * /usr/bin/flock -n /tmp/medium-sync.lock /home/noob/scripts/<your-browser-script> >> /home/noob/log/<job>.log 2>&1
```

`flock -n` skips the run entirely if the previous one still holds the lock.

## 3. systemd cgroup cap (the real safety net)

Run each browser job in a memory/CPU-capped cgroup, so a runaway browser is
OOM-killed **in its own scope** before it can touch the rest of the droplet.

Ad-hoc (wrap the cron command; `--user` since noob runs it, and lingering is already
enabled for `blizzard-jobs`):

```cron
*/30 * * * * systemd-run --user --scope -p MemoryMax=700M -p MemorySwapMax=256M -p CPUQuota=80% \
  /usr/bin/flock -n /tmp/medium-sync.lock /home/noob/scripts/<your-browser-script> \
  >> /home/noob/log/<job>.log 2>&1
```

Or, cleaner, a **user unit + timer** (`~/.config/systemd/user/`), which also gives
you journald logs and a start timeout:

`medium-sync.service`:
```ini
[Unit]
Description=Medium sync (browser automation)

[Service]
Type=oneshot
MemoryMax=700M
MemorySwapMax=256M
CPUQuota=80%
TimeoutStartSec=600
ExecStart=/usr/bin/flock -n /tmp/medium-sync.lock /home/noob/scripts/<your-browser-script>
```

`medium-sync.timer`:
```ini
[Unit]
Description=Run the Medium sync periodically

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now medium-sync.timer
```

`MemoryMax=700M` → if the job's browser tree exceeds 700 MB, only that cgroup is
OOM-killed. `CPUQuota=80%` → it can't peg the CPU. Tune to taste; the point is a hard
ceiling well under total RAM. (Needs cgroup v2 with user delegation — default on
recent Ubuntu.)

## 4. Fix the leak at source

The reaper/cap are backstops; also make the `/home/noob/scripts/*.py` Playwright jobs
close their browser deterministically:

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:              # guarantees teardown even on exception
    browser = p.chromium.launch(headless=True)
    try:
        page = browser.new_page()
        page.set_default_timeout(30_000)  # hard per-op timeout so a hang can't hold the browser
        # … work …
    finally:
        browser.close()
```

## Best: move it off prod

A 1.9 GB web server shouldn't host headless browsers at all. Prefer running these
jobs **locally** (like the Substack posting) or on a separate small worker. That
removes the failure mode entirely rather than just bounding it.

## <a name="swap"></a>Swap

Add a swap file as OOM insurance (turns a hard lockup into "slow but alive"):

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo -e 'vm.swappiness=10\nvm.vfs_cache_pressure=50' | sudo tee /etc/sysctl.d/99-swap.conf
sudo sysctl --system
```
