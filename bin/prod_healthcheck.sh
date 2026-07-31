#!/usr/bin/env bash
# Production health check for deploy verification. Exits non-zero if the site
# isn't serving, so the deploy workflow can roll back on a bad release.
#
# Usage: bin/prod_healthcheck.sh [URL] [EXPECTED_SUBSTRING]
#   URL                default https://mikeyclarke.co.nz/blog
#   EXPECTED_SUBSTRING optional text that must appear in the response body
#                      (use to assert a public-facing change is actually serving)
set -uo pipefail

URL="${1:-https://mikeyclarke.co.nz/blog}"
EXPECT="${2:-}"
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

code="$(curl -sS -o "$BODY" -w '%{http_code}' --max-time 20 "$URL" 2>/dev/null)"

if [ "$code" != "200" ]; then
  echo "FAIL: $URL returned HTTP ${code:-<no response>}"
  exit 1
fi

if [ -n "$EXPECT" ] && ! grep -qF -- "$EXPECT" "$BODY"; then
  echo "FAIL: $URL is 200 but body is missing expected text: $EXPECT"
  exit 1
fi

echo "OK: $URL returned 200${EXPECT:+ and contains \"$EXPECT\"}"
exit 0
