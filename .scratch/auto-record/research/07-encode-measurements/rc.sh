D=/tmp/claude-1000/-home-s1n7ax-Workspace-nixos/7c50c0fb-8ebb-448f-af01-c4fc4cd1433e/scratchpad/enc
cd "$D"
RAW="-f rawvideo -pix_fmt yuv420p -s 3440x1440 -r 50 -i raw420.yuv"
run() { # name, encoder, extra
  ffmpeg -y -v error $RAW -c:v "$2" -preset p4 -tune hq -pix_fmt yuv420p -g 100 \
    -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 $3 "r-$1.mkv" 2>/dev/null
  SZ=$(stat -c%s "r-$1.mkv")
  S=$(ffmpeg -hide_banner -nostats $RAW -i "r-$1.mkv" -frames:v 40 -lavfi "[0:v][1:v]ssim" -f null - 2>&1 | grep -oE "Y:[0-9.]+ " | head -1)
  echo "  $1: $((SZ*8*50/300/1000)) kbit/s  SSIM $S"
}
echo "### constqp, h264 (-bf 3)"
for QP in 16 20 24 28; do run "h264-qp$QP" h264_nvenc "-rc constqp -qp $QP -bf 3"; done
echo "### constqp, hevc (-bf 0)"
for QP in 16 20 24 28; do run "hevc-qp$QP" hevc_nvenc "-rc constqp -qp $QP -bf 0"; done
echo "### vbr+cq with qmin/qmax left at defaults (was 0/51 before)"
for CQ in 19 23 27; do run "h264-cqdef$CQ" h264_nvenc "-rc vbr -cq $CQ -b:v 0 -bf 3"; done
echo DONE
