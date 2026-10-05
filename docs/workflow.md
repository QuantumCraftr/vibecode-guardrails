# The workflow, in order

The point is not to run every tool every day. It is to run each check at the
moment it is cheap, and to make the loop automatic so it survives a busy week.

## The loop

```
        code / agent edit
              │
   ┌──────────▼──────────┐
   │ 1. pre-commit       │  secrets + dependency scan      (seconds)
   │    (automatic)      │
   └──────────┬──────────┘
              │  git commit
   ┌──────────▼──────────┐
   │ 2. pre-push / local │  SAST on the diff + deps        (~30 s - 3 min)
   │    (semi-auto)      │
   └──────────┬──────────┘
              │  git push / open PR
   ┌──────────▼──────────┐
   │ 3. CI on the PR     │  secrets + deps + SAST          (objective gate)
   └──────────┬──────────┘
              │  merge
   ┌──────────▼──────────┐
   │ 4. pre-deploy       │  DAST + containers + prod checkup
   │    (before release) │  + agent preflight              (minutes)
   └──────────┬──────────┘
              │  deploy
   ┌──────────▼──────────┐
   │ 5. after deploy     │  re-run prod-checkup on the URL
   └─────────────────────┘
```

## Level 1 — every commit (automatic)

Runs in the `pre-commit` hook, no thinking required. Blocks the commit on
failure.

- `gitleaks protect --staged` — refuses a staged secret.
- `osv-scanner --lockfile` (or `npm audit --audit-level=high`) — refuses a known
  vulnerable dependency.

Why here: a secret or a CVE entering the history is expensive to remove later.
This is the single highest-return check.

## Level 2 — before you push

- `semgrep scan --config=auto` on your changes — injection, XSS, weak crypto,
  unsafe deserialization, in **your** code.

Run it manually before a push, or wire it into a `pre-push` hook if your machine
is fast enough.

## Level 3 — CI on every PR

The `.github/workflows/security.yml` installed by this toolkit runs secrets +
deps + SAST on each push and PR. This is the check you cannot skip by being tired
or in a hurry. Make it a required check on the default branch.

## Level 4 — before a release

- **DAST**: `zap-baseline.py` against the app running locally or in staging. It
  crawls the real app and looks for missing headers, reflected input and common
  misconfigurations.
- **Containers**: `trivy fs .` and `trivy image <tag>` if you ship an image.
- **Production checkup**: `prod-checkup.sh` for `robots.txt`, `sitemap.xml`,
  `noindex`, security headers, `llms.txt`, and a form-abuse review.
- **Agent preflight**: `agent-preflight.sh` runs everything and prints a single
  pass/fail verdict you can paste into the PR.

## Level 5 — the local LLM, as a triage assistant only

Take the Semgrep/ZAP report and ask a local Qwen 8-14B to rank it: "classify
these findings by real risk for this app, mark likely false positives, list the
five to fix first". The model **reads and prioritises**. It never scans, never
decides the security boundary, and never gets write access during an audit.

An RTX 3070 8GB is more than enough for this lane.

## What does not belong in the loop

CTF/offensive benchmarks (like rangebench) measure whether a model can attack a
purpose-built target. They do not test the security of your application. Keep
them separate.

## Making it stick

1. Run the installer once per project.
2. Turn the CI workflow into a required check.
3. Keep `guardrails.config.json` in the repo and review it when the stack changes.
4. When a tool flags something, fix the whole class of issue, not just the line.
5. Never let the agent edit `scripts/guardrails/`, the hook or the CI workflow
   without asking; those are the rails.
