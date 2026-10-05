<!-- BEGIN:guardrails -->
## Security and production guardrails (do not skip)

This project uses `vibecode-guardrails`. Treat the rails as immutable: never edit
`scripts/guardrails/`, the git hook or `.github/workflows/security.yml` without
asking first. They are the boundary that makes fast, agent-assisted work safe.

### Before proposing any deploy or PR

Run `scripts/guardrails/agent-preflight.sh` and paste the verdict into the PR.
Do not claim the change is ready while a rail is failing.

### Rules an agent must follow here

- **Never commit a secret.** No API key, token, `.env` or credential in code,
  tests, fixtures, logs or commit messages. Read secrets from the environment.
- **Never weaken a security control to make a test pass.** No disabling auth,
  CORS, rate limiting, headers or captcha, and no `--no-verify` on a commit.
- **Never set a recipient, sender or provider from user input.** Mail routes are
  server-only; the recipient is fixed server-side.
- **Validate and rate-limit every public write** (form, webhook, API route):
  schema validation, a rate limit, and a captcha on anonymously reachable forms.
- **Do not touch indexing blindly.** `noindex`, `robots.txt` and metadata decide
  whether the site is discoverable. Verify intent before changing them.
- **Prefer the query builder / parameterised SQL.** No string-built queries.
- **Scope discipline.** Change only what the task requires; do not "tidy" or
  refactor neighbouring areas the task did not ask for.
- **Report honestly.** If a check was skipped or a tool was missing, say so; do
  not report a passing audit you did not run.

### What "done" means here

1. `agent-preflight.sh` passes (or the failures are explained and accepted).
2. The production checkup is green for a public-facing change.
3. No new tool warning was silenced without a written reason.
<!-- END:guardrails -->
