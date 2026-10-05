# vibecode-guardrails

> You ship fast, often with an AI writing half the code, and you do not read
> every line. That is fine. What is not fine is that your security then depends
> on you remembering to check. These rails make the tools refuse for you.

A one-command install that wires secrets, dependency, SAST and production checks
into the loop you already use (commit, push, CI, deploy), plus a contract that
stops an agent from quietly removing the checks.

Everything here is free and open source, or already on your machine. The value is
not the tools, it is the **wiring**.

## The problem, plainly

- You commit an API key once and it lives in the git history forever.
- A dependency ships a CVE and you only hear about it after an incident.
- The AI writes an injection, an XSS, or a contact form that a stranger turns
  into an open relay for their spam.
- The site goes live while still `noindex`, or without `robots.txt`,
  `sitemap.xml`, `llms.txt` or a single security header.
- The agent "improves" the project by loosening a control to make a test pass.

None of these are exotic. They are the boring, recurring accidents of building
fast, and each one has a cheap, deterministic check.

## Quickstart

From any project root:

```sh
curl -fsSL https://raw.githubusercontent.com/QuantumCraftr/vibecode-guardrails/main/install.sh | sh
```

Then:

```sh
scripts/guardrails/agent-preflight.sh    # one verdict: is this safe to ship?
```

That is the whole surface you need day to day. Everything else is configuration.

Want to try it on a repo **without committing anything**? Use ghost mode:

```sh
curl -fsSL https://raw.githubusercontent.com/QuantumCraftr/vibecode-guardrails/main/install.sh | sh -s -- --ghost
```

Ghost mode touches no tracked file and adds the toolkit to `.git/info/exclude`;
your `git status` stays clean.

## What you get

Three blocks, one CI gate:

| Block | Question it answers | What runs |
|---|---|---|
| **Security** | Is my code and my app safe? | secrets, dependencies, SAST, and DAST/containers before a release |
| **Production** | Is this ready to be public, and does it stay discoverable? | `robots.txt`, `sitemap.xml`, `llms.txt`, `noindex`, security headers, form-abuse review |
| **Agents** | Does the AI know the rules? | an `AGENTS.md` contract + an immutable preflight gate |
| **CI** | Who catches what I forget? | GitHub Actions running secrets + deps + SAST on every push and PR |

## The scripts

| Command | What it does | When |
|---|---|---|
| `security-audit.sh` | secrets, deps, SAST; `--dast=URL` for ZAP; `--container=IMG` for trivy | commits, PRs, before a release |
| `prod-checkup.sh` | robots/sitemap/`llms.txt`/noindex/headers/form abuse; `--url=` checks the live site | launch and every re-launch |
| `agent-preflight.sh` | chains both, prints a single PASS/FAIL to paste into a PR | before proposing a deploy |

Example output on a real Next.js project:

```
==> Production checkup
  ok robots.txt generated (src/app/robots.ts)
  ok sitemap generated (app router)
  ok llms.txt present
  ok no noindex found in source
  warn no security headers in next.config (HSTS, X-Frame-Options, CSP...)
  ok rate limiting detected
  warn no captcha on the public form
  warn Production checkup: passed with 2 warning(s)
```

Warnings are real, actionable findings, not noise.

## Install options

```sh
install.sh [project-dir] [--ghost] [--force]
```

- `--ghost` — local only; never touches a tracked file, keeps the toolkit out of
  git via `.git/info/exclude`.
- `--force` — allow overwriting a hook or CI file the tool does not own.

**Non-destructive by default.** The installer will not change an existing
`core.hooksPath`, will not overwrite a `pre-commit` hook it did not create (it
writes `pre-commit.guardrails` beside it), will not overwrite an existing CI
workflow or config, and only *appends* to `AGENTS.md`, never rewrites it.

## The workflow

```
code / agent edit
   │  pre-commit   → secrets + deps          (seconds, automatic)
   │  pre-push     → SAST on the change      (~30 s)
   │  CI on PR     → secrets + deps + SAST   (objective gate)
   │  pre-deploy   → DAST + prod checkup + agent preflight (minutes)
   │  post-deploy  → re-run prod checkup on the live URL
```

Full detail in [`docs/workflow.md`](docs/workflow.md).

## Where the AI fits (and does not)

A local LLM is genuinely useful for one thing here: after Semgrep or ZAP produce
a report, ask a Qwen 8-14B to rank it ("classify by real risk, flag likely false
positives, list the five to fix first"). A modest GPU is plenty.

It never scans, never decides the security boundary, and never gets write access
during an audit. **The AI proposes, a deterministic tool decides.**

## Documentation

- [`docs/workflow.md`](docs/workflow.md) — the day-to-day workflow, in order.
- [`docs/security.md`](docs/security.md) — what each security tool does and why,
  including the exact contact-form abuse pattern this prevents.
- [`docs/production.md`](docs/production.md) — the launch and re-launch checklist,
  with Next.js snippets.
- [`docs/agents.md`](docs/agents.md) — how to instruct coding agents safely.
- [`docs/tools.md`](docs/tools.md) — how to install each tool.

## Principles

- **Cheap checks run constantly, expensive checks run before shipping.**
- **A gate, not a report.** A check that only warns changes nothing.
- **The AI proposes, a deterministic tool decides.**
- **Rails are immutable.** If the agent can edit the check, it is not a boundary.
- **Fix the class, not the instance.** One flagged file means look for the pattern.

## License

MIT.
