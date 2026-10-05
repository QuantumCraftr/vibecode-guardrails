# Instructing coding agents safely

When you build fast with an agent, the risk is not that the model is bad at code.
It is that the model is confident, fast, and has no stake in the rules. The
`AGENTS.md` block this toolkit installs gives it a contract; the preflight script
gives both of you a verdict.

## The contract, in words

The agent may write application code. It may not:

- edit `scripts/guardrails/`, the git hook or `.github/workflows/security.yml`
  without asking (the rails),
- disable a security control to make something pass,
- commit secrets,
- take a recipient, sender or provider from user input,
- decide indexing (`noindex`, `robots.txt`) on its own,
- run `git commit --no-verify` or bypass a failing rail,
- report a passing audit it did not run.

It must, before proposing a deploy:

- run `scripts/guardrails/agent-preflight.sh` and paste the verdict,
- say honestly when a tool was missing or a check skipped.

## Why "the rails are immutable"

An agent optimising for the task will happily remove a check that is in its way.
If the agent can edit the check, the check is not a boundary. Keeping the rails
out of its scope is what makes "I don't read every line" safe.

## How to prompt for this

In the project's `AGENTS.md` (installed), plus in your prompt:

> Do not modify anything under `scripts/guardrails/`, `.githooks/` or
> `.github/workflows/security.yml`. Before you say this is ready, run
> `scripts/guardrails/agent-preflight.sh` and quote the result. If a check fails,
> fix the cause, never the check.

## Reviewing an agent's work

You do not need to read every line. You need to:

1. Look at the diff's **scope** — did it touch only what the task needed?
2. Run `agent-preflight.sh` and read the verdict.
3. Skim for the four recurring mistakes: a hard-coded secret, a relaxed control,
   user input reaching a recipient/sink, and a changed indexing directive.

## The LLM as a triage assistant

After Semgrep or ZAP produces a report, a local model (a Qwen 8-14B on a modest
GPU is plenty) can rank it: "classify by real risk for this app, flag likely
false positives, list the five to fix first". The model reads and prioritises.
It never scans, and it never gets write access during an audit.
