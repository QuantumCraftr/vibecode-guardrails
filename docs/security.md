# Security checks, and why each one exists

## gitleaks — secrets

A committed secret is the highest-impact, most common accident, and it is
expensive to remove because it lives in the git history even after you delete the
file. `gitleaks protect --staged` runs in the commit hook and refuses the commit
if a key, token or `.env` is staged.

Covers: API keys, tokens, private keys, connection strings, `.env` files.

If a secret did get committed: rotate it first (assume it is compromised), then
purge it from history and force-push, then add the pattern to `.gitleaks.toml`.

## osv-scanner / npm audit — dependencies

Your code is a small part of what you ship; the rest is dependencies. OSV checks
the lockfile against Google's vulnerability database. Runs on commit and in CI.

```sh
osv-scanner --lockfile=package-lock.json
npm audit --audit-level=high
```

## semgrep — SAST

Scans **your** code for classes of bug a rules engine recognises better than a
model does: string-built SQL, unsanitised output (XSS), weak crypto, unsafe
`eval`, path traversal, SSRF. `--config=auto` selects an appropriate ruleset.

Run on the diff before a push and in CI.

## OWASP ZAP — DAST

A different lens: it looks at the **running** app from the outside, the way an
attacker would. Baseline mode crawls and checks missing headers, reflected input,
cookie flags, common misconfigurations. It will not find your business-logic
bugs, and it produces some noise; use it before a release, not on every commit.

```sh
docker run -t ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t http://localhost:3000
```

## trivy — containers and filesystem

If you ship a container, the base image is part of your attack surface. `trivy
fs .` scans the project, `trivy image <tag>` the built image.

## The contact-form abuse pattern

A real incident this toolkit is designed to prevent: a `POST /api/contact` route
that called Resend with a `to` or `from` taken from the request. A stranger
scripted it and used the form as an open relay, flooding a third party and
bouncing the replies back to the owner.

The fix is structural, not a filter:

1. **The recipient is never user input.** Hard-code the destination server-side.
2. **Validate the body with a schema** (zod or equivalent) and reject unknown
   fields.
3. **Rate-limit by IP** (a token bucket, Upstash, or an in-memory limiter).
4. **Add a captcha** (Cloudflare Turnstile is free and invisible enough) on any
   anonymously reachable form.
5. **Never echo provider errors** to the client; log server-side.
6. **Cap sizes and content** (max length, no HTML, no headers injected).

`prod-checkup.sh` looks for the presence of rate limiting and a captcha whenever a
mail provider is detected.

## What this is not

It is not a substitute for a scoped penetration test, and it is not the CTF-style
offensive benchmarks that score a model's attack capability. Those measure the
model, not your app.
