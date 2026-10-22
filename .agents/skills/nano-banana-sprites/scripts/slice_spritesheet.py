#!/usr/bin/env python3
import argparse
import os
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, binary_dilation

def process_spritesheet(input_path: str, output_dir: str, target_w: int = 301, target_h: int = 288, min_size: int = 40):
    os.makedirs(output_dir, exist_ok=True)
    img = Image.open(input_path).convert("RGB")
    arr = np.array(img, dtype=np.uint8)

    sample_bg = arr[:40, :40].reshape(-1, 3).mean(axis=0)
    dist = np.linalg.norm(arr.astype(np.float32) - sample_bg, axis=2)

    bg_mask = dist < 120.0
    bg_mask_dilated = binary_dilation(bg_mask, iterations=1)

    is_fringe = ((arr[:, :, 0] > 70) & (arr[:, :, 2] > 70) & (arr[:, :, 1] < 60) & ~bg_mask_dilated)
    arr[is_fringe, 0] = 20
    arr[is_fringe, 1] = 22
    arr[is_fringe, 2] = 52

    alpha = np.ones((img.height, img.width), dtype=np.uint8) * 255
    alpha[bg_mask_dilated] = 0

    rgba = np.dstack([arr, alpha])

    mask = ~bg_mask_dilated
    labeled, _ = label(mask)
    slices = find_objects(labeled)
    large_slices = [s for s in slices if (s[0].stop - s[0].start) >= min_size and (s[1].stop - s[1].start) >= min_size]

    row_threshold = max(target_h, 200)
    large_slices.sort(key=lambda s: (s[0].start // row_threshold, s[1].start))

    if not large_slices:
        print(f"Warning: No sprite bounding boxes found exceeding {min_size}x{min_size} in {input_path}", file=sys.stderr)
        return

    for i, s in enumerate(large_slices):
        y_slice, x_slice = s
        sprite_rgba = rgba[y_slice, x_slice]
        sprite_img = Image.fromarray(sprite_rgba, "RGBA")

        canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
        max_draw_w = target_w - 20
        max_draw_h = target_h - 48
        scale = min(max_draw_w / sprite_img.width, max_draw_h / sprite_img.height)
        new_w = max(1, int(sprite_img.width * scale))
        new_h = max(1, int(sprite_img.height * scale))
        resized = sprite_img.resize((new_w, new_h), Image.Resampling.NEAREST)

        paste_x = (target_w - new_w) // 2
        paste_y = (target_h - 20) - new_h
        if paste_y < 10:
            paste_y = 10
        canvas.paste(resized, (paste_x, paste_y), resized)

        out_path = os.path.join(output_dir, f"{i:02d}.png")
        canvas.save(out_path)
        print(f"Exported frame {i:02d} -> {out_path} ({new_w}x{new_h})")

def main():
    parser = argparse.ArgumentParser(description="Slice pixel art spritesheet and produce transparent frames")
    parser.add_argument("input", help="Path to input spritesheet image")
    parser.add_argument("--out", "-o", default=".dumps/frames", help="Output directory")
    parser.add_argument("--width", "-W", type=int, default=301, help="Target canvas width (default: 301)")
    parser.add_argument("--height", "-H", type=int, default=288, help="Target canvas height (default: 288)")
    parser.add_argument("--min-size", "-m", type=int, default=40, help="Minimum width and height of sprite slice (default: 40)")
    args = parser.parse_args()

    process_spritesheet(args.input, args.out, args.width, args.height, args.min_size)

if __name__ == "__main__":
    main()
