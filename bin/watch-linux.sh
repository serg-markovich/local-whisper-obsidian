#!/bin/bash
set -euo pipefail

# Load config from ~/.config/local-whisper-obsidian/.env
# Override location by setting WHISPER_CONFIG env variable
ENV_FILE="${WHISPER_CONFIG:-$HOME/.config/local-whisper-obsidian/.env}"
[ -f "$ENV_FILE" ] || { echo "Config not found: $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

# Validate watch paths
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
[ ${#VALID[@]} -eq 0 ] && { echo "Error: no valid watch paths"; exit 1; }

PYTHON="$WHISPER_ENV/bin/python"
SCRIPT="$WHISPER_SRC/transcribe.py"

# ── Startup scan ─────────────────────────────────────────────────────────────
# Process any audio files that arrived while the service was offline.
# transcribe.py skips files that already have a .md alongside them.
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

# Use close_write to ensure the file is fully written before processing
inotifywait -m -e close_write -r "${VALID[@]}" --format "%w%f" \
    | while read -r file; do
        echo "$file" | grep -qiE '\.(m4a|mp3|wav|ogg|opus|webm|flac)$' || continue

        # Lockfile prevents parallel processing of the same file
        LOCK="/tmp/whisper-$(echo "$file" | md5sum | cut -c1-8).lock"
        exec 9>"$LOCK"
        flock -n 9 || { echo "Already processing: $file"; continue; }

        echo "New audio detected: $file"
        "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
            || echo "Failed to transcribe: $file"

        flock -u 9
    done
