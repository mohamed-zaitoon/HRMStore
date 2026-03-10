#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repository."
  exit 1
fi

REGEX_FILE=".protected-paths.regex"
if [[ ! -f "$REGEX_FILE" ]]; then
  echo "Missing $REGEX_FILE"
  exit 1
fi

mapfile -t TRACKED_FILES < <(git ls-files)
declare -a HITS=()
declare -A SEEN=()

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  if [[ -z "$line" ]] || [[ "${line:0:1}" == "#" ]]; then
    continue
  fi

  for file in "${TRACKED_FILES[@]}"; do
    if [[ "$file" =~ $line ]]; then
      if [[ -z "${SEEN[$file]+x}" ]]; then
        HITS+=("$file")
        SEEN[$file]=1
      fi
    fi
  done
done < "$REGEX_FILE"

if [[ "${#HITS[@]}" -eq 0 ]]; then
  echo "No tracked protected files found."
  exit 0
fi

echo "Tracked protected files:"
for file in "${HITS[@]}"; do
  echo "  - $file"
done
echo

if [[ "${1:-}" != "--apply" ]]; then
  echo "Dry run only."
  echo "Run with --apply to remove them from Git index (keep local files)."
  exit 0
fi

git rm --cached -- "${HITS[@]}"
echo
echo "Removed from Git index only."
echo "Next step: commit the changes."
