#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OUTDIR="$ROOT/SwiftTextDownload"
mkdir -p "$OUTDIR"

STAMP="$(date -u '+%a %d %b %Y %H:%M:%S %Z  (UTC)')"
GIT_HASH="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-git')"
REPO_URL="$(git remote get-url origin 2>/dev/null || echo 'local')"
OUT="$OUTDIR/SINGLE_SOURCE_OF_TRUTH_${GIT_HASH}_$(date -u '+%Y%m%d_%H%M%S').txt"

{
  echo "======================================================================"
  echo "HARD CANONICAL SOURCE — GolfAIApp Swift"
  echo "USE THIS DUMP ONLY. IGNORE ALL EARLIER DUMPS, SCREENSHOTS, OR CHAT CODE."
  echo "IF ANY SNIPPET CONFLICTS WITH THIS FILE, THIS FILE WINS."
  echo
  echo "Repo: $REPO_URL"
  echo "Commit: $GIT_HASH"
  echo "Timestamp: $STAMP"
  echo "======================================================================"
  echo
} > "$OUT"

while IFS= read -r f; do
  echo >> "$OUT"
  printf "%s\n" "$(basename "$f")" >> "$OUT"
  printf "FILE: %s\n\n" "$f" >> "$OUT"
  cat "$f" >> "$OUT"
  printf "\n\n" >> "$OUT"
done < <(
  find "$ROOT" -type f -name '*.swift' \
    -not -path '*/Pods/*' \
    -not -path '*/Carthage/*' \
    -not -path '*/.build/*' \
    -not -path '*/.git/*' \
    -not -path '*/DerivedData/*' \
    -not -path '*/.restore_backups/*' \
    -print0 | tr '\0' '\n' | LC_ALL=C sort
)

echo "Wrote: $OUT"
open "$OUT" >/dev/null 2>&1 || true
