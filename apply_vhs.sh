#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############# CONFIG — edit if your paths differ #############
CLI="/Applications/ntsc-rs.app/Contents/MacOS/ntsc-rs-cli"
PRESET="$HOME/Desktop/VHS_PRESETS.json"
IN_DIR="$HOME/Desktop/DOWNSAMPLED_MP4"
OUT_DIR="$HOME/Desktop/VHS VIDEOS"
# File types to process (case-insensitive)
EXTS=("mp4" "mov" "mkv" "avi")
##############################################################

# --- Basic checks ---
[[ -x "$CLI" ]] || { echo "❌ CLI not found/executable at: $CLI"; exit 1; }
[[ -f "$PRESET" ]] || { echo "❌ Preset file not found at: $PRESET"; exit 1; }
[[ -d "$IN_DIR" ]] || { echo "❌ Input folder not found at: $IN_DIR"; exit 1; }

mkdir -p "$OUT_DIR"

# Build find predicate for extensions
ext_pred=()
for e in "${EXTS[@]}"; do
  ext_pred+=( -iname "*.${e}" -o )
done
# remove trailing -o
unset 'ext_pred[${#ext_pred[@]}-1]'

echo "▶️  Scanning input…"
count=0

# Find files safely (handles spaces/newlines)
find "$IN_DIR" -type f \( "${ext_pred[@]}" \) -print0 | while IFS= read -r -d '' file; do
  ((count++)) || true
  # relative path within IN_DIR (preserve subfolders)
  rel="${file#"$IN_DIR"/}"
  # split name & extension
  filename="$(basename "$rel")"
  ext="${filename##*.}"
  name="${filename%.*}"

  # destination path mirrors folder structure; add _VHS before extension
  dest_dir="$OUT_DIR/$(dirname "$rel")"
  dest_file="$dest_dir/${name}_VHS.${ext}"

  mkdir -p "$dest_dir"

  echo "🎞️  [$count] Processing: $rel"
  "$CLI" \
    --input "$file" \
    --output "$dest_file" \
    --settings-path "$PRESET" \
    --overwrite
done

echo "✅ Done. Check: $OUT_DIR"

