set -e
D=/tmp/claude-1000/-home-s1n7ax-Workspace-nixos/7c50c0fb-8ebb-448f-af01-c4fc4cd1433e/scratchpad/enc
cd $D
# a tall page of real code/text, rendered once
cat /home/s1n7ax/Workspace/nixos/.scratch/auto-record/map.md /home/s1n7ax/Workspace/nixos/.scratch/auto-record/issues/*.md > text.txt
head -c 60000 text.txt > text-trim.txt
magick -background '#1e1e2e' -fill '#cdd6f4' -font DejaVu-Sans-Mono -pointsize 17 \
  label:@text-trim.txt -resize 3440x\> -gravity northwest -extent 3440x png24:text.png
identify text.png
# circle mask (ticket 04: 540px, 3px feather)
magick -size 540x540 xc:none -fill white -draw "circle 269.5,269.5 269.5,2" \
  -channel A -blur 0x1.5 -level 0,100% +channel png32:mask.png
identify mask.png
