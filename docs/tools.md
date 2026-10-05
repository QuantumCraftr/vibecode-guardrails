# Installing the tools

All free and open source. Install what you can; the scripts treat a missing tool
as a warning, not a failure, so you can adopt progressively.

## Required for the highest-value checks

**gitleaks** (secret scanning) — the single most important one.

```sh
# macOS
brew install gitleaks
# Linux (binary)
curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz | tar xz
sudo mv gitleaks /usr/local/bin/
# or via docker
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect -s /repo
```

**osv-scanner** (vulnerable dependencies) — or rely on `npm audit`.

```sh
# macOS / Linux via Go
go install github.com/google/osv-scanner/cmd/osv-scanner@latest
# or docker
docker run --rm -v "$PWD:/src" ghcr.io/google/osv-scanner:latest --lockfile=/src/package-lock.json
```

## For deeper code analysis

**semgrep** (SAST, finds injection/XSS/etc.).

```sh
pipx install semgrep      # or: pip install semgrep
# usage
semgrep scan --config=auto
```

## Before a release

**OWASP ZAP** (DAST, against a running app). Docker is the easiest path.

```sh
docker run -t ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://localhost:3000 -r report.html
```

**trivy** (containers, filesystem, IaC).

```sh
brew install aquasecurity/trivy/trivy   # or docker: aquasec/trivy
trivy fs .
trivy image your-app:tag
```

## Optional, for history and triage

**trufflehog** — scans the whole git history, not just staged changes.

```sh
docker run --rm -v "$PWD:/p" trufflesecurity/trufflehog:latest filesystem /p
```

**A local LLM for triage** — not a scanner. Point it at a Semgrep/ZAP report and
ask it to rank findings. Ollama or LM Studio with a Qwen 8-14B is plenty.

## Verify the install

```sh
scripts/guardrails/security-audit.sh
```

Anything not installed shows as a warning, with the exact install line above.
