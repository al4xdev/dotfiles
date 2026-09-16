# Mobile media recipes

## Inspect a recording

```bash
ffprobe -v error -show_entries stream=width,height,avg_frame_rate,duration \
  -of default=nw=1 capture.webm

ffmpeg -hide_banner -loglevel error -i capture.webm \
  -vf "fps=4,scale=240:-1,tile=4x3" contact-sheet.png
```

Use a contact sheet to locate the useful interval, then inspect individual frames around every
large visual change.

## Trim without changing the source

```bash
ffmpeg -hide_banner -loglevel error -ss 1.2 -to 4.8 -i capture.webm \
  -an -c:v libvpx-vp9 -crf 32 -b:v 0 trimmed.webm
```

Put `-ss` after `-i` when frame-accurate trimming matters more than speed.

## Make a README GIF

```bash
ffmpeg -hide_banner -loglevel error -i trimmed.webm \
  -vf "fps=15,scale=780:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=sierra2_4a" \
  gesture.gif
```

If the GIF is too large, shorten it first; then reduce fps, width, or palette size. Do not destroy
text readability merely to hit an arbitrary byte count.

## Make a still

```bash
ffmpeg -hide_banner -loglevel error -i capture.png \
  -vf "scale=900:-2:flags=lanczos" -compression_level 6 capture.webp
```

Keep PNG when small text becomes visibly softer in WebP.

## Evidence checklist

- No secrets, notifications, cursor accidents, or personal identifiers.
- No loading spinner unless loading is the subject.
- First and last states remain readable long enough.
- Touch direction matches the state change.
- File size and dimensions are recorded.
- Relative documentation paths resolve from the containing document.
