#!/usr/bin/env bash
# usage: measure.sh <label>   e.g. measure.sh stills | measure.sh movie
set -uo pipefail
L="${1:?label}"
SP="$(cd "$(dirname "$0")" && pwd)"
D="$SP/$L"; mkdir -p "$D"
SECS="${SECS:-70}"

exec > >(tee "$D/log.txt") 2>&1

echo "===== $L  ($(date -Is)) ====="
echo "--- auto-detect ---";      gphoto2 --auto-detect
echo "--- summary ---";          gphoto2 --summary 2>&1 | head -40
echo "--- config: output ---";   gphoto2 --get-config output 2>&1 | head -20
echo "--- config: liveview-ish ---"
gphoto2 --list-config 2>/dev/null | grep -Ei 'viewfinder|liveview|evf|movie|output|aspect|zoom|autofocus|focus' || echo "(none matched)"
for c in /main/settings/output /main/actions/viewfinder /main/capturesettings/aspectratio \
         /main/settings/evfmode /main/capturesettings/liveviewsize /main/actions/eoszoom; do
  gphoto2 --get-config "$c" 2>/dev/null | sed "s|^|[$c] |" | head -12
done

echo "--- single preview frame ---"
rm -f "$D/preview.jpg"
gphoto2 --set-config viewfinder=1 --capture-preview --filename "$D/preview.jpg" --force-overwrite
ls -l "$D/preview.jpg" 2>/dev/null

echo "--- ${SECS}s movie stream ---"
gphoto2 --stdout --set-config viewfinder=1 --capture-movie="${SECS}s" \
  | python3 "$SP/timed_capture.py" "$D/stream.mjpg"

echo "--- stream analysis ---"
python3 "$SP/mjpeg_stat.py" "$D/stream.mjpg" "$SECS"
echo "===== done: $D ====="
