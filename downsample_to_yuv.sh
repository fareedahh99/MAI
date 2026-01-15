#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
IN_DIR="$HOME/Desktop/CLEAN_VIDEOS"           # source videos
OUT_DIR="$HOME/Desktop/DOWNSAMPLED_MP4"       # where downsampled .mp4 will be saved
RESOLUTION="720x576"                          # use "720x576" for PAL, "720x480" for NTSC
PIX_FMT="yuv420p"
# ==============

mkdir -p "$OUT_DIR"

echo "🎞️  Starting downsampling from: $IN_DIR"
count=0; ok=0; fail=0
FAILED_LIST="$OUT_DIR/failed_list.txt"
: > "$FAILED_LIST"

# Find input videos robustly
find "$IN_DIR" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" \) -print0 |
while IFS= read -r -d '' file; do
  ((count++)) || true
  base="$(basename "${file%.*}")"
  out_mp4="$OUT_DIR/${base}_downsampled.mp4"

  # Verify input path
  if ! stat "$file" >/dev/null 2>&1; then
    ((fail++)) || true
    printf '⛔ [%d] stat failed for: %q\n' "$count" "$file" | tee -a "$FAILED_LIST"
    printf '     bytes: ' | tee -a "$FAILED_LIST"; printf '%s' "$file" | od -An -t x1 | tr -d '\n' | tee -a "$FAILED_LIST"; echo | tee -a "$FAILED_LIST"
    continue
  fi

  printf '📉 [%d] Downsampling: %q -> %q\n' "$count" "$file" "$out_mp4"

  clean_file=$(printf '%s' "$file" | tr -d '\r' | sed 's/[[:space:]]*$//')

  # Detect original FPS to preserve timing
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
        -of default=nk=1:nw=1 "$clean_file" 2>/dev/null || echo "")
  [[ -z "${fps}" || "${fps}" == "0/0" ]] && fps="30"

  # Downsample and re-encode directly to MP4
  if ffmpeg -nostdin -hide_banner -loglevel error -y \
      -i "$clean_file" \
      -vf "scale=$RESOLUTION" -pix_fmt "$PIX_FMT" -r "$fps" \
      -c:v libx264 -preset slow -crf 18 -movflags +faststart \
      "$out_mp4"; then
    ((ok++)) || true
    printf '✅ [%d] Wrote: %q\n' "$count" "$out_mp4"
  else
    ((fail++)) || true
    printf '❌ [%d] ffmpeg failed: %q\n' "$count" "$file" | tee -a "$FAILED_LIST"
  fi
done

printf '\nDone. Converted videos: %d  Failed: %d\nOutput dir: %q\n' "$ok" "$fail" "$OUT_DIR"
if (( fail > 0 )); then
  echo "See failure details in: $FAILED_LIST"
fi
