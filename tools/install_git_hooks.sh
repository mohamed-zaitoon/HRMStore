#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository."
  exit 1
fi

if [[ ! -x ".githooks/pre-push" ]]; then
  echo "Missing .githooks/pre-push or file is not executable."
  exit 1
fi

git config core.hooksPath .githooks

echo "Installed Git hooks path: .githooks"
echo "Current value: $(git config --get core.hooksPath)"
