D=/tmp/claude-1000/-home-s1n7ax-Workspace-nixos/7c50c0fb-8ebb-448f-af01-c4fc4cd1433e/scratchpad/enc
cd "$D"
RAW="-f rawvideo -pix_fmt yuv420p -s 3440x1440 -r 50 -i raw420.yuv"
for O in cq-17.mkv cq-19.mkv cq-21.mkv cq-23.mkv cq-25.mkv cq-28.mkv hevc-cq-21.mkv hevc-cq-23.mkv; do
  S=$(ffmpeg -hide_banner -nostats $RAW -i "$O" -frames:v 40 -lavfi "[0:v][1:v]ssim" -f null - 2>&1 | grep -oE "SSIM Y:[0-9.]+.*All:[0-9.]+")
  SZ=$(stat -c%s "$O")
  echo "  $O  $((SZ*8*50/300/1000)) kbit/s  $S"
done
echo DONE
