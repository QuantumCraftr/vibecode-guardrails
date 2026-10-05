#!/usr/bin/env sh
# Production checkup: is this project ready to be public, and does it stay
# discoverable once it is?
#
# In a Next.js project it inspects the app router for metadata, robots,
# sitemap, llms.txt and a security-header config. With a live URL it also checks
# the deployed response. With no Next.js it still checks for a public/robots.txt,
# a sitemap and an llms.txt.
#
# Usage:
#   scripts/guardrails/prod-checkup.sh                # local static checks
#   scripts/guardrails/prod-checkup.sh --url=https://example.com
#
# Exit code: 1 on a blocking problem (e.g. a live site that is still noindex).

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"

ROOT=$(pwd)
URL=""
for arg in "$@"; do case "$arg" in --url=*) URL="${arg#*=}" ;; esac; done

info "Production checkup in $ROOT"
IS_NEXT=0
[ -f next.config.ts ] || [ -f next.config.js ] || [ -f next.config.mjs ] && IS_NEXT=1
APP_DIR=""
[ -d src/app ] && APP_DIR="src/app"
[ -d app ] && APP_DIR="app"

# --- robots.txt -----------------------------------------------------------
if [ -f public/robots.txt ]; then
  ok "robots.txt present (public/robots.txt)"
elif [ "$IS_NEXT" = "1" ] && [ -f "${APP_DIR}/robots.ts" ]; then
  ok "robots.txt generated (${APP_DIR}/robots.ts)"
else
  fail "robots.txt missing"; inc_fail
  note "add public/robots.txt or ${APP_DIR}/robots.ts"
fi

# A robots.txt or metadata that blocks everything is the #1 launch mistake.
if [ -f public/robots.txt ] && grep -qiE '^\s*Disallow:\s*/\s*$' public/robots.txt 2>/dev/null; then
  fail "robots.txt disallows everything (Disallow: /)"; inc_fail
fi

# --- sitemap --------------------------------------------------------------
if [ -f public/sitemap.xml ]; then
  ok "sitemap.xml present"
elif [ "$IS_NEXT" = "1" ] && { [ -f "${APP_DIR}/sitemap.ts" ] || [ -f "${APP_DIR}/sitemap.xml" ]; }; then
  ok "sitemap generated (app router)"
else
  warn "sitemap.xml not found"; inc_warn
fi

# --- llms.txt -------------------------------------------------------------
if [ -f public/llms.txt ] || [ -f "${APP_DIR}/llms.txt" ] || { [ "$IS_NEXT" = "1" ] && [ -f "${APP_DIR}/llms.txt/route.ts" ]; }; then
  ok "llms.txt present"
else
  warn "llms.txt not found (helps AI crawlers cite the site correctly)"; inc_warn
fi

# --- noindex sniffing -----------------------------------------------------
info "Scanning for noindex / indexing blockers"
NOINDEX_HITS=$(grep -rIl --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' -E 'noindex|noIndex|robots:\s*\{?\s*index:\s*false' . 2>/dev/null | grep -v node_modules | grep -v '.next' | head -20)
if [ -n "$NOINDEX_HITS" ]; then
  warn "possible noindex present in source:"; inc_warn
  printf '%s\n' "$NOINDEX_HITS" | sed 's/^/      /'
  note "verify this is intentional per-page, not global"
else
  ok "no noindex found in source"
fi

# --- security headers -----------------------------------------------------
if [ "$IS_NEXT" = "1" ]; then
  if grep -rIqE 'Strict-Transport-Security|X-Frame-Options|Content-Security-Policy|headers\s*\(' next.config.* 2>/dev/null; then
    ok "security headers configured in next.config"
  else
    warn "no security headers in next.config (HSTS, X-Frame-Options, CSP...)"; inc_warn
    note "add a headers() block; see docs/production.md"
  fi
fi

# --- contact form abuse ---------------------------------------------------
if grep -rIl --include='*.ts' --include='*.tsx' -E 'resend|sendgrid|nodemailer|mailgun|postmark' . 2>/dev/null | grep -v node_modules >/dev/null; then
  info "Mail provider detected; checking for abuse controls"
  RATE=0; CAPTCHA=0
  grep -rIl --include='*.ts' --include='*.tsx' -E 'ratelimit|rate-limit|rateLimit|upstash|limiter' . 2>/dev/null | grep -v node_modules >/dev/null && RATE=1
  grep -rIl --include='*.ts' --include='*.tsx' -E 'turnstile|hcaptcha|recaptcha|captcha' . 2>/dev/null | grep -v node_modules >/dev/null && CAPTCHA=1
  [ "$RATE" = "1" ] && ok "rate limiting detected" || { fail "no rate limiting around the mail route"; inc_fail; }
  [ "$CAPTCHA" = "1" ] && ok "captcha detected" || warn "no captcha on the public form"; inc_warn
  note "also lock the sender/recipient: never let a user set the recipient, and never return provider errors to the client"
fi

# --- live URL checks ------------------------------------------------------
if [ -n "$URL" ]; then
  info "Live checks against $URL"
  if have curl; then
    HDRS=$(curl -sI -L "$URL" 2>/dev/null)
    BODY=$(curl -s -L "$URL" 2>/dev/null | head -c 200000)

    printf '%s' "$HDRS" | grep -qiE '^strict-transport-security:' && ok "live: HSTS header" || { warn "live: no HSTS header"; inc_warn; }
    printf '%s' "$HDRS" | grep -qiE '^x-content-type-options:' && ok "live: X-Content-Type-Options" || { warn "live: no X-Content-Type-Options"; inc_warn; }
    printf '%s' "$HDRS" | grep -qiE '^x-frame-options:|^content-security-policy:.*frame-ancestors' && ok "live: frame protection" || { warn "live: no frame protection"; inc_warn; }

    if printf '%s' "$BODY" | grep -qiE '<meta[^>]+name=["'"'"']robots["'"'"'][^>]+noindex'; then
      fail "live: page is serving noindex"; inc_fail
    else
      ok "live: page is indexable"
    fi

    code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/robots.txt" 2>/dev/null)
    [ "$code" = "200" ] && ok "live: /robots.txt 200" || { warn "live: /robots.txt returned $code"; inc_warn; }
    code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/sitemap.xml" 2>/dev/null)
    [ "$code" = "200" ] && ok "live: /sitemap.xml 200" || { warn "live: /sitemap.xml returned $code"; inc_warn; }
  else
    warn "live: curl not available"; inc_warn
  fi
fi

summary "Production checkup"
