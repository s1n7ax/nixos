set -u
D=/tmp/claude-1000/-home-s1n7ax-Workspace-nixos/7c50c0fb-8ebb-448f-af01-c4fc4cd1433e/scratchpad/enc
cd "$D"; N=300
RAW420="-f rawvideo -pix_fmt yuv420p -s 3440x1440 -r 50 -i raw420.yuv"
ssim() { ffmpeg -v error $RAW420 -i "$1" -frames:v 30 -lavfi "[0:v][1:v]ssim" -f null - 2>&1 | grep -oE "Y:[0-9.]+|All:[0-9.]+" | tr '\n' ' '; }

echo "### h264_nvenc 420 p4 -bf 3 : cq sweep"
for CQ in 17 19 21 23 25 28; do
  O=cq-$CQ.mkv
  [ -f "$O" ] || ffmpeg -y -v error $RAW420 -c:v h264_nvenc -preset p4 -tune hq -rc vbr -cq $CQ -qmin 0 -qmax 51 -b:v 0 \
    -pix_fmt yuv420p -g 50 -bf 3 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 "$O" 2>/dev/null
  SZ=$(stat -c%s "$O"); KB=$((SZ*8*50/N/1000))
  echo "  cq=$CQ  ${KB} kbit/s  40min=$(echo "scale=2; $KB*2400/8/1000000" | bc)GB  $(ssim $O)"
done
echo
echo "### hevc_nvenc 420 p4 -bf 0 (Pascal rejects -bf>0)"
for CQ in 21 23; do
  O=hevc-cq-$CQ.mkv
  ffmpeg -y -v error $RAW420 -c:v hevc_nvenc -preset p4 -tune hq -rc vbr -cq $CQ -qmin 0 -qmax 51 -b:v 0 \
    -pix_fmt yuv420p -g 50 -bf 0 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 "$O" 2>/dev/null
  SZ=$(stat -c%s "$O"); echo "  hevc cq=$CQ  $((SZ*8*50/N/1000)) kbit/s  $(ssim $O)"
done
echo
echo "### GOP cost at cq21"
for G in 50 100 250; do
  ffmpeg -y -v error $RAW420 -c:v h264_nvenc -preset p4 -tune hq -rc vbr -cq 21 -b:v 0 \
    -pix_fmt yuv420p -g $G -bf 3 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 "g-$G.mkv" 2>/dev/null
  echo "  -g $G = $((G/50))s keyframes: $(stat -c%s g-$G.mkv) B"
done
echo
echo "### the real CUDA graph, per main pix_fmt"
for PF in yuv420p yuv444p; do
  SRC=raw420.yuv; [ $PF = yuv444p ] && SRC=raw444.yuv
  echo -n "  main=$PF: "
  if ffmpeg -y -v error -f rawvideo -pix_fmt $PF -s 3440x1440 -r 50 -i $SRC \
    -loop 1 -framerate 50 -i mask.png \
    -filter_complex "[0:v]hwupload_cuda[m];[1:v]format=yuva420p,hwupload_cuda[o];[m][o]overlay_cuda=x=2860:y=860:eof_action=pass" \
    -frames:v 20 -c:v h264_nvenc -preset p4 -cq 21 -b:v 0 "cuda-$PF.mkv" 2>cuda-$PF.err; then
    echo "OK $(stat -c%s cuda-$PF.mkv) B"
  else
    echo "FAILED: $(head -2 cuda-$PF.err | tr '\n' ' ')"
  fi
done
echo
echo "### idle: real static desktop capture at cq21"
ffmpeg -y -v error -i src.mkv -c:v h264_nvenc -preset p4 -tune hq -rc vbr -cq 21 -b:v 0 \
  -pix_fmt yuv420p -g 50 -bf 3 -spatial-aq 1 -aq-strength 8 -rc-lookahead 20 idle.mkv 2>&1 | head -2
echo "  idle: $(stat -c%s idle.mkv) B / 13.76 s = $(echo "scale=0; $(stat -c%s idle.mkv)*8/13.76/1000" | bc) kbit/s"
echo DONE
