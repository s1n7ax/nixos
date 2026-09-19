set -u
D=/tmp/claude-1000/-home-s1n7ax-Workspace-nixos/7c50c0fb-8ebb-448f-af01-c4fc4cd1433e/scratchpad/enc
cd $D
N=300
SCROLL="-loop 1 -framerate 50 -i text.png -vf crop=3440:1440:0:'min(t*444\,ih-1440)'"

echo "### phase0: build raw yuv420p + yuv444p scroll sources ($N frames)"
ffmpeg -y -v error -loop 1 -framerate 50 -i text.png \
  -vf "crop=3440:1440:0:'min(t*444,ih-1440)',format=yuv420p" -frames:v $N -f rawvideo raw420.yuv
ffmpeg -y -v error -loop 1 -framerate 50 -i text.png \
  -vf "crop=3440:1440:0:'min(t*444,ih-1440)',format=yuv444p" -frames:v $N -f rawvideo raw444.yuv
ls -la raw420.yuv raw444.yuv

echo
echo "### phase1: decode-only ceiling (is the source the bottleneck?)"
ffmpeg -y -v error -benchmark -f rawvideo -pix_fmt yuv420p -s 3440x1440 -r 50 -i raw420.yuv -f null - 2>&1 | tail -2

echo
echo "### phase2: throughput + bitrate, cq 21"
for spec in "h264_nvenc yuv420p p4 raw420.yuv" "h264_nvenc yuv420p p7 raw420.yuv" \
            "h264_nvenc yuv444p p4 raw444.yuv" "h264_nvenc yuv444p p7 raw444.yuv" \
            "hevc_nvenc yuv420p p4 raw420.yuv" "hevc_nvenc yuv420p p7 raw420.yuv" \
            "hevc_nvenc yuv444p p4 raw444.yuv"; do
  set -- $spec; ENC=$1; PF=$2; PR=$3; SRC=$4
  OUT="o-$ENC-$PF-$PR.mkv"
  echo "--- $ENC $PF $PR"
  /usr/bin/env time -f "wall %e s" ffmpeg -y -v error -stats_period 1000 \
    -f rawvideo -pix_fmt $PF -s 3440x1440 -r 50 -i $SRC \
    -c:v $ENC -preset $PR -tune hq -rc vbr -cq 21 -qmin 0 -qmax 51 -b:v 0 \
    -pix_fmt $PF -g 50 -bf 3 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 \
    "$OUT" 2>&1 | tail -4
  if [ -f "$OUT" ]; then
    SZ=$(stat -c%s "$OUT")
    echo "    size=${SZ}B  bitrate=$(( SZ*8*50/N/1000 )) kbit/s"
  fi
done
