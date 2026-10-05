# vibecode-guardrails

Security and production guardrails for projects you build fast, often with an AI
agent doing part of the work. The premise is simple: your discipline cannot be
"I will be careful". The tools must refuse to let a secret, a vulnerable
dependency or an unsafe deploy slip through, even when you did not read every
line.

Nothing here is exotic or paid. Every tool is free and open source, or already
on your machine. The value is the **wiring**: one install command puts the checks
in the loop (commit, push, CI, pre-deploy), and an `AGENTS.md` block tells coding
agents the project's rules so they stop reintroducing the same mistakes.

## What it protects against

- A secret committed by accident (API key, token, `.env`).
- A dependency with a known CVE shipping to production.
- An injection or XSS the agent wrote without realising.
- A vibe-coded contact form that becomes an open relay for a stranger's spam.
- A site that goes live while still `noindex`, or that ships without `robots.txt`,
  `sitemap.xml`, `llms.txt` or a security header policy.
- An agent that "improves" the project by editing outside its remit.

## The three blocks

| Block | Question it answers | Checks |
|---|---|---|
| **Security** | Is my code and my app safe? | secrets, dependencies, SAST, DAST, containers |
| **Production** | Is this ready to be public? | `noindex`, `robots.txt`, `sitemap.xml`, `llms.txt`, security headers, form abuse |
| **Agents** | Does the AI know the rules? | `AGENTS.md` contract, scope limits, pre-commit gate |

Plus **CI**: a GitHub Actions workflow that runs the same checks on every push so
the guardrail does not depend on you remembering.

## Install in an existing project

From your project root:

```sh
curl -fsSL https://raw.githubusercontent.com/QuantumCraftr/vibecode-guardrails/main/install.sh | sh
```

Or, after cloning this repo somewhere:

```sh
/path/to/vibecode-guardrails/install.sh /path/to/your/project
```

The installer detects the stack (Node/Next.js, Python, generic), copies the
scripts into `scripts/guardrails/`, drops a `pre-commit` hook, the CI workflow,
an `AGENTS.md` block and a `guardrails.config.json` you can edit. It never
overwrites an existing hook or `AGENTS.md` without telling you.

## Run it by hand

```sh
scripts/guardrails/security-audit.sh     # secrets + deps + SAST + optional DAST
scripts/guardrails/prod-checkup.sh       # robots/sitemap/noindex/headers/llms.txt
scripts/guardrails/agent-preflight.sh    # everything a deploy should pass
```

## Read this first

- [`docs/workflow.md`](docs/workflow.md) — the day-to-day workflow, in order.
- [`docs/security.md`](docs/security.md) — what each security tool does and why.
- [`docs/production.md`](docs/production.md) — the launch and re-launch checklist.
- [`docs/agents.md`](docs/agents.md) — how to instruct coding agents safely.
- [`docs/tools.md`](docs/tools.md) — how to install each tool.

## Philosophy

- **Cheap checks run constantly, expensive checks run before shipping.** A secret
  scan on every commit; a DAST against a real app only before a release.
- **A gate, not a report.** A check that only prints a warning changes nothing.
- **The AI proposes, a deterministic tool decides.** Never ask a model to be the
  security boundary.
- **Fix the class, not the instance.** When a tool flags one file, look for the
  pattern across the project.

## License

MIT.
