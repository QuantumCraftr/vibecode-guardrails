#!/usr/bin/env sh
# Install vibecode-guardrails into a project.
#
# Usage:
#   ./install.sh [project-dir]        # default: current directory
#
# What it does:
#   - copies the guardrail scripts to <project>/scripts/guardrails/
#   - installs a pre-commit hook (never overwrites an existing one silently)
#   - drops .github/workflows/security.yml
#   - appends a guardrails block to AGENTS.md (and a Next.js block if detected)
#   - writes guardrails.config.json if absent
#
# It is idempotent: re-running updates the managed files and leaves your edits to
# guardrails.config.json and AGENTS.md intact.

set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-$PWD}
DEST=$(cd "$DEST" && pwd)

echo "vibecode-guardrails -> $DEST"

# 1. Scripts ---------------------------------------------------------------
mkdir -p "$DEST/scripts/guardrails/hooks"
cp "$SRC/scripts/lib.sh" "$DEST/scripts/guardrails/lib.sh"
cp "$SRC/scripts/security-audit.sh" "$DEST/scripts/guardrails/security-audit.sh"
cp "$SRC/scripts/prod-checkup.sh" "$DEST/scripts/guardrails/prod-checkup.sh"
cp "$SRC/scripts/agent-preflight.sh" "$DEST/scripts/guardrails/agent-preflight.sh"
chmod +x "$DEST/scripts/guardrails/"*.sh
echo "  scripts/guardrails/ installed"

# 2. Hook ------------------------------------------------------------------
HOOK_DIR="$DEST/.githooks"
mkdir -p "$HOOK_DIR"
if [ -f "$HOOK_DIR/pre-commit" ] && ! grep -q "guardrails" "$HOOK_DIR/pre-commit" 2>/dev/null; then
  echo "  warn: .githooks/pre-commit exists and is not ours; left untouched"
  echo "        merge it by hand with scripts/guardrails/hooks/pre-commit"
else
  cp "$SRC/hooks/pre-commit" "$HOOK_DIR/pre-commit"
  chmod +x "$HOOK_DIR/pre-commit"
  echo "  .githooks/pre-commit installed"
fi
if [ -d "$DEST/.git" ]; then
  ( cd "$DEST" && git config core.hooksPath .githooks )
  echo "  core.hooksPath set to .githooks"
else
  echo "  note: not a git repo yet; run 'git config core.hooksPath .githooks' after git init"
fi

# 3. CI --------------------------------------------------------------------
mkdir -p "$DEST/.github/workflows"
if [ -f "$DEST/.github/workflows/security.yml" ]; then
  echo "  .github/workflows/security.yml exists; left untouched"
else
  cp "$SRC/ci/security.yml" "$DEST/.github/workflows/security.yml"
  echo "  .github/workflows/security.yml installed"
fi

# 4. AGENTS.md -------------------------------------------------------------
if [ -f "$DEST/AGENTS.md" ]; then
  if grep -q "BEGIN:guardrails" "$DEST/AGENTS.md"; then
    echo "  AGENTS.md already has the guardrails block; left untouched"
  else
    printf '\n' >> "$DEST/AGENTS.md"
    cat "$SRC/agents/AGENTS.block.md" >> "$DEST/AGENTS.md"
    echo "  guardrails block appended to AGENTS.md"
  fi
else
  cat "$SRC/agents/AGENTS.block.md" > "$DEST/AGENTS.md"
  echo "  AGENTS.md created with the guardrails block"
fi

# 5. Next.js block ---------------------------------------------------------
IS_NEXT=0
[ -f "$DEST/next.config.ts" ] || [ -f "$DEST/next.config.js" ] || [ -f "$DEST/next.config.mjs" ] && IS_NEXT=1
if [ "$IS_NEXT" = "1" ] && ! grep -q "BEGIN:guardrails-nextjs" "$DEST/AGENTS.md" 2>/dev/null; then
  printf '\n' >> "$DEST/AGENTS.md"
  cat "$SRC/agents/AGENTS.nextjs.block.md" >> "$DEST/AGENTS.md"
  echo "  Next.js block appended to AGENTS.md"
fi

# 6. Config ----------------------------------------------------------------
if [ ! -f "$DEST/guardrails.config.json" ]; then
  cp "$SRC/guardrails.config.json.example" "$DEST/guardrails.config.json"
  echo "  guardrails.config.json created"
else
  echo "  guardrails.config.json exists; left untouched"
fi

echo ""
echo "Done. Next:"
echo "  1. read $SRC/docs/workflow.md"
echo "  2. install the tools: $SRC/docs/tools.md"
echo "  3. run: scripts/guardrails/agent-preflight.sh"
