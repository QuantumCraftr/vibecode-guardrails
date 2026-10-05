#!/usr/bin/env sh
# Security audit: secrets, dependencies, SAST, and optionally DAST + containers.
# Safe to run anywhere; nothing is modified.
#
# Usage:
#   scripts/guardrails/security-audit.sh              # secrets + deps + SAST
#   scripts/guardrails/security-audit.sh --dast URL   # also run ZAP baseline
#   scripts/guardrails/security-audit.sh --container IMAGE
#   scripts/guardrails/security-audit.sh --full URL   # everything available
#
# Exit code: 1 if any check failed, 0 otherwise.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"

ROOT=$(pwd)
DAST_URL=""
CONTAINER_IMAGE=""
for arg in "$@"; do
  case "$arg" in
    --dast=*) DAST_URL="${arg#*=}" ;;
    --container=*) CONTAINER_IMAGE="${arg#*=}" ;;
    --full=*) DAST_URL="${arg#*=}" ;;
  esac
done

info "Security audit in $ROOT"

# 1. Secrets ---------------------------------------------------------------
if have gitleaks; then
  if [ -d .git ]; then
    run_check "secrets: gitleaks (working tree)" gitleaks detect --no-banner --redact -s . || true
  else
    warn "secrets: not a git repository, skipped"; inc_warn
  fi
else
  warn "secrets: gitleaks not installed (see docs/tools.md)"; inc_warn
fi

# 2. Dependencies ----------------------------------------------------------
if [ -f package-lock.json ]; then
  if have osv-scanner; then
    run_check "dependencies: osv-scanner" osv-scanner --lockfile=package-lock.json || true
  elif have npm; then
    run_check "dependencies: npm audit" npm audit --audit-level=high || true
  else
    warn "dependencies: neither osv-scanner nor npm found"; inc_warn
  fi
elif [ -f pnpm-lock.yaml ] && have pnpm; then
  run_check "dependencies: pnpm audit" pnpm audit --audit-level high || true
elif [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if have pip-audit; then
    run_check "dependencies: pip-audit" pip-audit || true
  else
    warn "dependencies: pip-audit not installed"; inc_warn
  fi
else
  note "dependencies: no lockfile detected, skipped"
fi

# 3. SAST ------------------------------------------------------------------
if have semgrep; then
  run_check "sast: semgrep (auto)" semgrep scan --config=auto --error --quiet --metrics=off || true
else
  warn "sast: semgrep not installed (see docs/tools.md)"; inc_warn
fi

# 4. DAST (optional) -------------------------------------------------------
if [ -n "$DAST_URL" ]; then
  if have docker; then
    info "DAST: ZAP baseline against $DAST_URL"
    if docker run --rm -t ghcr.io/zaproxy/zaproxy:stable \
        zap-baseline.py -t "$DAST_URL" -m 3 -I >/tmp/guardrails-zap.$$ 2>&1; then
      ok "dast: ZAP baseline"
    else
      fail "dast: ZAP baseline found issues (see output below)"
      sed 's/^/      /' /tmp/guardrails-zap.$$ | tail -40
      inc_fail
    fi
    rm -f /tmp/guardrails-zap.$$
  else
    warn "dast: docker not available, skipped"; inc_warn
  fi
fi

# 5. Containers (optional) -------------------------------------------------
if [ -n "$CONTAINER_IMAGE" ]; then
  if have trivy; then
    run_check "container: trivy image $CONTAINER_IMAGE" trivy image --severity HIGH,CRITICAL --exit-code 1 "$CONTAINER_IMAGE" || true
  else
    warn "container: trivy not installed"; inc_warn
  fi
fi

summary "Security audit"
