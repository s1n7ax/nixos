#!/usr/bin/env bash
# PROTOTYPE — throwaway. Renders circle-overlay variants onto a mock 3440x1440 screen.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out
W=3440; H=1440; M=40; CROP="crop=576:576:224:0"

mask() { # diameter feather outfile
  ffmpeg -v error -y -f lavfi \
    -i "color=c=black:s=$1x$1,format=gray,geq=lum='clip(($1/2-hypot(X-($1/2-0.5),Y-($1/2-0.5)))*255/$2,0,255)'" \
    -frames:v 1 "$3"
}

pos() { # diameter corner -> "x:y"
  local D=$1
  case $2 in
    br) echo "$((W-D-M)):$((H-D-M))" ;;
    bl) echo "$M:$((H-D-M))" ;;
    tr) echo "$((W-D-M)):$M" ;;
    tl) echo "$M:$M" ;;
  esac
}

# plain: camera masked to a circle, no ring
plain() { # diameter feather corner out
  local D=$1 F=$2 XY; XY=$(pos "$D" "$3")
  mask "$D" "$F" "out/.m$D-$F.png"
  ffmpeg -v error -y -i screen.png -i cam.png -i "out/.m$D-$F.png" -filter_complex \
    "[1:v]$CROP,scale=$D:$D,format=rgba[c];[2:v]format=gray[m];[c][m]alphamerge[k];[0:v][k]overlay=$XY" \
    -frames:v 1 "$4"
}

# ring: camera inset by B px on a solid disc of COLOR
ring() { # diameter border color feather corner out
  local D=$1 B=$2 C=$3 F=$4 XY I; XY=$(pos "$D" "$5"); I=$((D-2*B))
  mask "$D" "$F" "out/.m$D-$F.png"
  ffmpeg -v error -y -i screen.png -i cam.png -i "out/.m$D-$F.png" -filter_complex \
    "[1:v]$CROP,scale=$I:$I,pad=$D:$D:$B:$B:$C,format=rgba[c];[2:v]format=gray[m];[c][m]alphamerge[k];[0:v][k]overlay=$XY" \
    -frames:v 1 "$6"
}

# shadow: soft dark disc behind, then the camera circle
shadow() { # diameter spread corner out
  local D=$1 S=$2 XY SD SX SY; XY=$(pos "$D" "$3")
  SD=$((D+2*S)); read -r SX SY <<<"$(pos "$D" "$3" | tr ':' ' ')"
  mask "$D" 2 "out/.m$D-2.png"; mask "$SD" "$((S*2))" "out/.s$SD.png"
  ffmpeg -v error -y -i screen.png -i cam.png -i "out/.m$D-2.png" -i "out/.s$SD.png" -filter_complex \
    "[3:v]format=gray,geq=lum='0.62*p(X,Y)'[sm];color=c=black:s=${SD}x${SD},format=rgba[sc];[sc][sm]alphamerge[sh];
     [1:v]$CROP,scale=$D:$D,format=rgba[c];[2:v]format=gray[m];[c][m]alphamerge[k];
     [0:v][sh]overlay=$((SX-S)):$((SY-S+6))[bg];[bg][k]overlay=$XY" \
    -frames:v 1 "$4"
}

echo "== edge treatments (420px, bottom-right)"
plain  420 1 br out/edge-a-hard.png
plain  420 3 br out/edge-b-soft.png
ring   420 5 white 3 br out/edge-c-white-ring.png
ring   420 6 0x1e1e2e 3 br out/edge-d-dark-ring.png
shadow 420 14 br out/edge-e-shadow.png

echo "== sizes (soft edge, bottom-right)"
for D in 300 420 540 660; do plain "$D" 3 br "out/size-$D.png"; done

echo "== corners (420px, soft edge)"
for C in br bl tr tl; do plain 420 3 "$C" "out/corner-$C.png"; done

echo "== phone simulations (660px, soft edge, bottom-right)"
plain 660 3 br out/.phone-src.png
ffmpeg -v error -y -i out/.phone-src.png -vf scale=390:-2:flags=lanczos out/phone-portrait-390.png
ffmpeg -v error -y -i out/.phone-src.png -vf scale=844:-2:flags=lanczos out/phone-landscape-844.png
plain 420 3 br out/.phone-src2.png
ffmpeg -v error -y -i out/.phone-src2.png -vf scale=390:-2:flags=lanczos out/phone-portrait-390-at420.png
ffmpeg -v error -y -i out/.phone-src2.png -vf scale=844:-2:flags=lanczos out/phone-landscape-844-at420.png

rm -f out/.m*.png out/.s*.png out/.phone-src*.png
echo done
