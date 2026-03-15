#!/bin/bash
set -euo pipefail

# Check dependencies
if ! command -v fswatch &>/dev/null; then
    echo "Error: fswatch not found."
    echo "Install it with: brew install fswatch"
    exit 1
fi

# Load config
ENV_FILE="${WHISPER_CONFIG:-$HOME/.config/local-whisper-obsidian/.env}"
[ -f "$ENV_FILE" ] || { echo "Config not found: $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

# Check filesystem access (macOS Full Disk Access may block vault paths)
if ! ls "${SCAN_PATHS%%:*}" &>/dev/null; then
    echo "Error: cannot access ${SCAN_PATHS%%:*}"
    echo "macOS may require Full Disk Access for Terminal."
    echo "System Settings → Privacy & Security → Full Disk Access"
    exit 1
fi

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

# Wait until file size is stable (replaces fixed sleep)
wait_for_stable() {
    local file="$1"
    local prev=-1 curr
    while true; do
        curr=$(stat -f%z "$file" 2>/dev/null || echo -1)
        [ "$curr" = "$prev" ] && [ "$curr" != "-1" ] && break
        prev=$curr
        sleep 0.5
    done
}

# ── Startup scan ─────────────────────────────────────────────────────────────
echo "Startup scan: checking for unprocessed files..."
for p in "${VALID[@]}"; do
    find "$p" -maxdepth 1 -type f \
        | { grep -iE '\.(m4a|mp3|wav|ogg|opus|webm|flac)$' || true; } \
        | while read -r file; do
            wait_for_stable "$file"
            echo "Found unprocessed: $file"
            "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
                || echo "Failed to transcribe: $file"
        done
done
echo "Startup scan complete."
# ─────────────────────────────────────────────────────────────────────────────

# Deduplication: skip if same file seen within last 5 seconds
LAST_FILE=""
LAST_TIME=0

fswatch -0 -e ".*" -i "\.(m4a|mp3|wav|ogg|opus|webm|flac)$" "${VALID[@]}" \
| while IFS= read -r -d "" file; do
    NOW=$(date +%s)
    if [ "$file" = "$LAST_FILE" ] && [ $((NOW - LAST_TIME)) -lt 5 ]; then
        echo "Skipping duplicate event: $file"
        continue
    fi
    LAST_FILE="$file"
    LAST_TIME=$NOW

    wait_for_stable "$file"
    echo "New audio detected: $file"
    "$PYTHON" "$SCRIPT" "$file" --model "$MODEL" --language "$LANGUAGE" \
        || echo "Failed to transcribe: $file"
done
