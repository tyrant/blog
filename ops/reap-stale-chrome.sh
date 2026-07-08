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

pgrep -f "$PATTERN" | while read -r pid; do
  etimes=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ') || continue
  [ -n "$etimes" ] || continue
  if (( etimes >= MAX_SEC )); then
    pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
    echo "$(date -Is) reaping chrome pid=$pid pgid=$pgid age=${etimes}s"
    kill -TERM "-${pgid}" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  fi
done
