#!/usr/bin/env sh
# Shared helpers for the guardrail scripts. POSIX sh, no dependencies.
# Source it: . "$(dirname "$0")/lib.sh"

# --- output ----------------------------------------------------------------
if [ -t 1 ]; then
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m'); C_YELLOW=$(printf '\033[33m')
  C_BLUE=$(printf '\033[34m'); C_DIM=$(printf '\033[2m'); C_OFF=$(printf '\033[0m')
else
  C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_DIM=; C_OFF=
fi

info()  { printf '%s\n' "${C_BLUE}==>${C_OFF} $*"; }
ok()    { printf '%s\n' "${C_GREEN}  ok${C_OFF} $*"; }
warn()  { printf '%s\n' "${C_YELLOW}  warn${C_OFF} $*"; }
fail()  { printf '%s\n' "${C_RED}  fail${C_OFF} $*"; }
note()  { printf '%s\n' "${C_DIM}      $*${C_OFF}"; }

# Global counters, used by the summary.
FAILURES=0
WARNINGS=0
inc_fail() { FAILURES=$((FAILURES + 1)); }
inc_warn() { WARNINGS=$((WARNINGS + 1)); }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, print ok/fail, and increment counters. Skips if the binary is
# missing and SKIP_MISSING=1 (default): a missing tool is a warning, not a fail,
# so a fresh machine is not blocked before it has installed anything.
run_check() {
  _name=$1; shift
  if ! have "$1"; then
    if [ "${SKIP_MISSING:-1}" = "1" ]; then
      warn "$_name skipped ($1 not installed)"; inc_warn; return 0
    fi
    fail "$_name: required tool $1 is not installed"; inc_fail; return 1
  fi
  if "$@" >/tmp/guardrails-out.$$ 2>&1; then
    ok "$_name"
    return 0
  else
    fail "$_name"
    sed 's/^/      /' /tmp/guardrails-out.$$ | head -40
    rm -f /tmp/guardrails-out.$$
    inc_fail
    return 1
  fi
}

# --- config ----------------------------------------------------------------
# Reads guardrails.config.json if jq is present, otherwise falls back to defaults
# via grep. Keeps the toolkit dependency-free.
config_get() {
  _key=$1; _default=$2
  _cfg="$(dirname "$0")/../../guardrails.config.json"
  [ -f "$_cfg" ] || _cfg="$PWD/guardrails.config.json"
  if [ -f "$_cfg" ] && have jq; then
    _val=$(jq -r --arg k "$_key" 'getpath($k|split(".")) // empty' "$_cfg" 2>/dev/null)
    if [ -n "$_val" ] && [ "$_val" != "null" ]; then printf '%s' "$_val"; return; fi
  fi
  printf '%s' "$_default"
}

# --- summary ---------------------------------------------------------------
summary() {
  _title=$1
  printf '\n'
  if [ "$FAILURES" -gt 0 ]; then
    fail "$_title: $FAILURES failure(s), $WARNINGS warning(s)"
    return 1
  fi
  if [ "$WARNINGS" -gt 0 ]; then
    warn "$_title: passed with $WARNINGS warning(s)"
    return 0
  fi
  ok "$_title: all checks passed"
  return 0
}
