#!/bin/sh
# Run once per clone: wires this repo to use githooks/ for Git hooks.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
git config core.hooksPath githooks
chmod +x githooks/pre-commit 2>/dev/null || true
echo "core.hooksPath set to githooks (pre-commit will scan for secrets)."
