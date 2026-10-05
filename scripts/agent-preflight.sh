#!/usr/bin/env sh
# One command a coding agent (or you) runs before proposing a deploy. It chains
# the security audit and the production checkup and prints a single verdict,
# suitable to paste into a PR description.
#
# Usage:
#   scripts/guardrails/agent-preflight.sh
#   scripts/guardrails/agent-preflight.sh --url=https://example.com --dast=https://staging.example.com

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"

URL=""
DAST=""
for arg in "$@"; do
  case "$arg" in
    --url=*) URL="${arg#*=}" ;;
    --dast=*) DAST="${arg#*=}" ;;
  esac
done

info "Agent preflight: security audit then production checkup"
printf '\n'

SEC_ARGS=""
[ -n "$DAST" ] && SEC_ARGS="--dast=$DAST"
# shellcheck disable=SC2086
"$HERE/security-audit.sh" $SEC_ARGS
SEC_RC=$?

printf '\n'
if [ -n "$URL" ]; then
  "$HERE/prod-checkup.sh" "--url=$URL"
else
  "$HERE/prod-checkup.sh"
fi
PROD_RC=$?

printf '\n'
if [ "$SEC_RC" = "0" ] && [ "$PROD_RC" = "0" ]; then
  ok "PREFLIGHT PASSED: safe to propose a deploy"
  exit 0
fi
fail "PREFLIGHT FAILED: fix the items above before deploying"
exit 1
