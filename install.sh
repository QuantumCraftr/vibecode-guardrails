#!/usr/bin/env sh
# Install vibecode-guardrails into a project.
#
# Usage:
#   ./install.sh [project-dir] [--ghost] [--force]
#
#   --ghost   install for local use only: never touch a tracked file (no
#             AGENTS.md edit, no CI file), and add the tooling to
#             .git/info/exclude so nothing is committed. Ideal to try it out or
#             to keep your own projects clean.
#   --force   allow overwriting an existing hook / CI file / AGENTS.md block that
#             this tool did not create. Without it, the installer never
#             overwrites anything it does not own.
#
# Default behaviour is deliberately conservative:
#   - never changes core.hooksPath if you already set one
#   - never overwrites an existing pre-commit hook it does not own
#   - never overwrites an existing CI workflow or guardrails.config.json
#   - only appends an AGENTS.md block, and never removes or rewrites yours
#
# It is idempotent: re-running updates the managed files and leaves your edits to
# guardrails.config.json and AGENTS.md intact.

set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=$PWD
GHOST=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --ghost) GHOST=1 ;;
    --force) FORCE=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) DEST=$arg ;;
  esac
done
DEST=$(cd "$DEST" && pwd)

echo "vibecode-guardrails -> $DEST"
[ "$GHOST" = "1" ] && echo "  mode: ghost (nothing tracked will be touched or added to git)"

# 1. Scripts (always safe: our own directory) ------------------------------
mkdir -p "$DEST/scripts/guardrails/hooks"
cp "$SRC/scripts/lib.sh" "$DEST/scripts/guardrails/lib.sh"
cp "$SRC/scripts/security-audit.sh" "$DEST/scripts/guardrails/security-audit.sh"
cp "$SRC/scripts/prod-checkup.sh" "$DEST/scripts/guardrails/prod-checkup.sh"
cp "$SRC/scripts/agent-preflight.sh" "$DEST/scripts/guardrails/agent-preflight.sh"
cp "$SRC/hooks/pre-commit" "$DEST/scripts/guardrails/hooks/pre-commit"
chmod +x "$DEST/scripts/guardrails/"*.sh "$DEST/scripts/guardrails/hooks/pre-commit"
echo "  scripts/guardrails/ installed"

# 2. Hook ------------------------------------------------------------------
HOOK_DIR="$DEST/.githooks"
HOOK_FILE="$HOOK_DIR/pre-commit"
mkdir -p "$HOOK_DIR"
if [ -f "$HOOK_FILE" ] && ! grep -q "guardrails" "$HOOK_FILE" 2>/dev/null; then
  if [ "$FORCE" = "1" ]; then
    cp "$SRC/hooks/pre-commit" "$HOOK_FILE"
    echo "  .githooks/pre-commit overwritten (--force)"
  else
    cp "$SRC/hooks/pre-commit" "$HOOK_DIR/pre-commit.guardrails"
    echo "  warn: .githooks/pre-commit already exists; wrote pre-commit.guardrails instead"
    echo "        merge it by hand, or re-run with --force to overwrite"
  fi
else
  cp "$SRC/hooks/pre-commit" "$HOOK_FILE"
  echo "  .githooks/pre-commit installed"
fi
chmod +x "$HOOK_DIR/pre-commit" "$HOOK_DIR/pre-commit.guardrails" 2>/dev/null || true

# core.hooksPath: only set it if none is configured. Never clobber a project's
# existing hook path (a common, destructive surprise).
if [ -d "$DEST/.git" ]; then
  CURRENT_HOOKS=$(cd "$DEST" && git config --get core.hooksPath || true)
  if [ -z "$CURRENT_HOOKS" ]; then
    ( cd "$DEST" && git config core.hooksPath .githooks )
    echo "  core.hooksPath set to .githooks"
  elif [ "$CURRENT_HOOKS" = ".githooks" ]; then
    echo "  core.hooksPath already .githooks"
  else
    echo "  note: core.hooksPath is '$CURRENT_HOOKS', left untouched"
    echo "        to also run guardrails, add this to that hook: sh scripts/guardrails/hooks/pre-commit"
  fi
else
  echo "  note: not a git repo yet; run 'git config core.hooksPath .githooks' after git init"
fi

# 3. CI --------------------------------------------------------------------
if [ "$GHOST" = "1" ]; then
  echo "  CI: skipped in ghost mode (would create a tracked file)"
else
  mkdir -p "$DEST/.github/workflows"
  if [ -f "$DEST/.github/workflows/security.yml" ]; then
    echo "  .github/workflows/security.yml exists; left untouched"
  else
    cp "$SRC/ci/security.yml" "$DEST/.github/workflows/security.yml"
    echo "  .github/workflows/security.yml installed"
  fi
fi

# 4. AGENTS.md (only append our block; never rewrite the file) -------------
if [ "$GHOST" = "1" ]; then
  echo "  AGENTS.md: skipped in ghost mode (would edit a tracked file)"
else
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
fi

# 5. Next.js block ---------------------------------------------------------
if [ "$GHOST" = "0" ] && [ -f "$DEST/AGENTS.md" ]; then
  IS_NEXT=0
  { [ -f "$DEST/next.config.ts" ] || [ -f "$DEST/next.config.js" ] || [ -f "$DEST/next.config.mjs" ]; } && IS_NEXT=1
  if [ "$IS_NEXT" = "1" ] && ! grep -q "BEGIN:guardrails-nextjs" "$DEST/AGENTS.md" 2>/dev/null; then
    printf '\n' >> "$DEST/AGENTS.md"
    cat "$SRC/agents/AGENTS.nextjs.block.md" >> "$DEST/AGENTS.md"
    echo "  Next.js block appended to AGENTS.md"
  fi
fi

# 6. Config ----------------------------------------------------------------
if [ ! -f "$DEST/guardrails.config.json" ]; then
  cp "$SRC/guardrails.config.json.example" "$DEST/guardrails.config.json"
  echo "  guardrails.config.json created"
else
  echo "  guardrails.config.json exists; left untouched"
fi

# 7. Ghost mode: keep everything out of git via the local, uncommitted exclude.
if [ "$GHOST" = "1" ] && [ -d "$DEST/.git" ]; then
  EXCLUDE="$DEST/.git/info/exclude"
  touch "$EXCLUDE"
  if ! grep -q "vibecode-guardrails" "$EXCLUDE"; then
    cat >> "$EXCLUDE" <<'EOF'

# vibecode-guardrails (local only, never committed)
.githooks/
.github/workflows/security.yml
guardrails.config.json
scripts/guardrails/
EOF
    echo "  .git/info/exclude updated (toolkit stays local)"
  else
    echo "  .git/info/exclude already excludes vibecode-guardrails"
  fi
fi

echo ""
echo "Done. Next:"
echo "  1. read $SRC/docs/workflow.md"
echo "  2. install the tools: $SRC/docs/tools.md"
echo "  3. run: sh$([ "$GHOST" = "1" ] && echo " scripts/guardrails/agent-preflight.sh" || echo " scripts/guardrails/agent-preflight.sh")"
