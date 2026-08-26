#!/bin/bash
# One-time setup: install repo-local git hooks.
# Run this after cloning: bash tools/setup-hooks.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Pre-push hook: runs swift test + core node tests before every push
if [ ! -L "$HOOKS_DIR/pre-push" ] && [ ! -f "$HOOKS_DIR/pre-push" ]; then
  ln -sf "../../tools/pre-push-hook.sh" "$HOOKS_DIR/pre-push"
  chmod +x "$REPO_ROOT/tools/pre-push-hook.sh"
  echo "✓ Installed pre-push hook (swift test + node contracts before push)"
elif [ -L "$HOOKS_DIR/pre-push" ]; then
  echo "✓ Pre-push hook already installed"
else
  echo "⚠ Pre-push hook exists but is not a symlink — skipping"
  echo "  To replace: rm $HOOKS_DIR/pre-push && bash $0"
fi
