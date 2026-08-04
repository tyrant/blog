#!/usr/bin/env bash
#
# Backstop reaper for headless Chromium left over from browser automation.
# Kills (by process group) any automation Chrome older than MAX_MIN minutes, so a
# leaked/hung browser can't accumulate and exhaust the box. Never touches a real
# interactive browser — it only matches the automation profiles below.
#
# Install (on prod, as noob):
#   mkdir -p ~/bin ~/log && cp ops/reap-stale-chrome.sh ~/bin/ && chmod +x ~/bin/reap-stale-chrome.sh
#   crontab -e   # add:
#   */5 * * * * /home/noob/bin/reap-stale-chrome.sh 10 >> /home/noob/log/chrome-reaper.log 2>&1
#
# Usage: reap-stale-chrome.sh [MAX_MIN]   (default 10)
set -euo pipefail

MAX_SEC=$(( ${1:-10} * 60 ))

# Only automation browsers — adjust the profile names to match your scripts.
PATTERN='chrom.*(playwright_profile|medium_playwright_profile|--headless)'

# A browser driven by a live script isn't leaked — skip so we never kill an
# active run. Heart/clap backlogs legitimately run well over MAX_MIN minutes,
# and killing their browser mid-run aborts the whole run (TargetClosedError).
if pgrep -f 'scripts/(substack_heart|medium_clap)\.py' >/dev/null 2>&1; then
  exit 0
fi

# Capture first (pgrep exits non-zero when nothing matches — normal, not an error).
pids=$(pgrep -f "$PATTERN" || true)
[ -n "$pids" ] || exit 0

for pid in $pids; do
  etimes=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || true)
  [ -n "$etimes" ] || continue
  if (( etimes >= MAX_SEC )); then
    pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
    [ -n "$pgid" ] || continue
    echo "$(date -Is) reaping chrome pid=$pid pgid=$pgid age=${etimes}s"
    kill -TERM "-${pgid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  fi
done
