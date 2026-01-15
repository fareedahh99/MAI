#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ---- CONFIG ----
PEXELS_API_KEY="FTwTbInl0qAuR0FDiMGZVwsmkmarfOSGbZisNCagNGCdEAobXt20tmx7"
OUT_DIR="$HOME/Desktop/CLEAN_VIDEOS"
TARGET=850
PER_PAGE=80                   # Pexels max per page
QUERIES=(nature forest river mountains beach city street urban architecture buildings skyline indoor kitchen living room office library classroom people portraits group crowd market vehicles car traffic train bus bicycle animals dog cat birds wildlife sports running basketball football tennis objects tools electronics books plants signs billboards storefronts)
MIN_WIDTH=720                 # pick file >= this width
CONCURRENT=8                  # parallel downloads
MIN_DUR=8                     # <<< NEW: keep clips at least 5s
MAX_DUR=60  
# ----------------

mkdir -p "$OUT_DIR"
tmp_links="$(mktemp)"
: > "$tmp_links"

page=1
downloaded=0

header_auth=(-H "Authorization: $PEXELS_API_KEY")

# Keep fetching pages across multiple queries until we reach TARGET
while (( downloaded < TARGET )); do
  for q in "${QUERIES[@]}"; do
    echo "🔎 Searching: $q (page $page)"
    json="$(curl -sS -G https://api.pexels.com/videos/search \
      "${header_auth[@]}" \
      --data-urlencode "query=$q" \
      --data-urlencode "per_page=$PER_PAGE" \
      --data-urlencode "page=$page")"

    # Extract a single good file link per video (>= MIN_WIDTH), prefer nearest >= MIN_WIDTH
    echo "$json" | jq -r --argjson minw "$MIN_WIDTH" '
      .videos[]?
      | (.video_files
          | sort_by(.width)
          | (map(select(.width >= $minw)) + .)
          | first
        )?.link
    ' | sed '/^null$/d' >> "$tmp_links"

    # de-duplicate, stop at TARGET
    sort -u "$tmp_links" -o "$tmp_links"
    current_total=$(wc -l < "$tmp_links")
    echo "   collected links: $current_total"
    if (( current_total >= TARGET )); then
      break 2
    fi
  done
  ((page++))
done

echo "🚀 Downloading $(wc -l < "$tmp_links") videos to $OUT_DIR …"
# Use aria2 for fast, parallel, resumable downloads
aria2c -x16 -s16 -j"$CONCURRENT" -c -d "$OUT_DIR" -i "$tmp_links"

# --- NEW: rename sequentially to VID_1, VID_2, … (kept minimal; everything else untouched) ---
# --- rename sequentially to VID_1, VID_2, … ---
i=1
# Get a stable order (by path); avoid ls/SIGPIPE. macOS-safe.
while IFS= read -r f; do
  ext="${f##*.}"
  ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"  # lowercase extension (macOS-safe)
  new="$OUT_DIR/VID_$i.$ext_lc"
  while [[ -e "$new" ]]; do
    i=$((i+1))
    new="$OUT_DIR/VID_$i.$ext_lc"
  done
  mv -n "$f" "$new"
  i=$((i+1))
done < <(find "$OUT_DIR" -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' \) -print | sort)

echo "✅ Renamed files to VID_1, VID_2, …"

echo "✅ Done. Saved to: $OUT_DIR"
