#!/bin/bash
set -euo pipefail

# Docker entrypoint — env vars come from container environment, no .env file.
# Required: SCAN_PATHS
# Optional: MODEL (default: small), LANGUAGE (default: auto)

MODEL="${MODEL:-small}"
LANGUAGE="${LANGUAGE:-auto}"

: "${SCAN_PATHS:?SCAN_PATHS is not set. Example: -e SCAN_PATHS=/vault/0_inbox:/vault/1_journal/assets}"

PYTHON="python3"
SCRIPT="/app/src/transcribe.py"

IFS=':' read -ra RAW_PATHS <<< "$SCAN_PATHS"
VALID=()
for p in "${RAW_PATHS[@]}"; do
  if [ -d "$p" ]; then
    VALID+=("$p")
    echo "Watching: $p"
  else
    echo "Warning: path not found, skipping: $p"
  fi
done
[ ${#VALID[@]} -eq 0 ] && { echo "Error: no valid watch paths found"; exit 1; }

echo "Model: $MODEL | Language: $LANGUAGE"

# ── Startup scan ─────────────────────────────────────────────────────────────
echo "Startup scan: checking for unprocessed files..."
for p in "${VALID[@]}"; do
    find "$p" -maxdepth 1 -type f \
        | { grep -iE '\.(m4a|mp3|wav|ogg|opus|webm|flac)$' || true; } \
        | while read -r file; do
            echo "Found unprocessed: $file"
            "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
                || echo "Failed to transcribe: $file"
        done
done
echo "Startup scan complete."
# ─────────────────────────────────────────────────────────────────────────────

inotifywait -m -e close_write -r "${VALID[@]}" --format "%w%f" \
| while read -r file; do
  echo "$file" | grep -qiE '\.(m4a|mp3|wav|ogg|opus|webm|flac)$' || continue

  LOCK="/tmp/whisper-$(echo "$file" | md5sum | cut -c1-8).lock"
  exec 9>"$LOCK"
  flock -n 9 || { echo "Already processing: $file"; continue; }

  echo "New audio detected: $file"
  "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
    || echo "Failed to transcribe: $file"

  flock -u 9
done
