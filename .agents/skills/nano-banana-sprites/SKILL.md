---
name: nano-banana-sprites
description: >-
  Generate consistent pixel art animation spritesheets and transparent PNG frames using headless
  Antigravity CLI (agy -p) with Google Gemini / Nano Banana, complete with automated chroma key
  slicing and JPEG de-fringing. Usable by any AI coding agent (Claude Code, Cursor, Copilot, DSH, Aider).
---

# Nano Banana & Gemini Pixel Sprites (Cross-Agent Universal Skill)

This skill enables **any AI agent** (Claude Code, Cursor, Copilot, DSH, Aider, etc.) running in a shell to generate consistent 16-bit pixel art animation sequences and convert them into transparent PNG frames using headless Antigravity CLI (`agy`) and Google Gemini / Nano Banana image generation.

---

## Why Headless `agy`?

External agents (Cursor, Claude Code, Aider, etc.) often lack direct multimodal image generation tooling or require external API keys, SDK setups, and billing configurations.

By invoking the local `agy` CLI in headless prompt mode (`agy -p "..." --dangerously-skip-permissions`), any AI agent can delegate visual generation directly to the local Antigravity runtime, utilizing Gemini's multimodal image generation (Nano Banana) without additional credentials or configuration.

---

## Critical Prompt Engineering Rules for Pixel Art

When generating pixel art via diffusion models:

1. **NEVER request "transparent background"**:
   - Models frequently misunderstand transparency and draw an un-removable fake checkerboard pattern (`checkerboard alpha pattern`).
2. **ALWAYS demand pure solid Chroma Key Magenta (`#FF00FF`)**:
   - Specify: `solid pure uniform chroma key magenta background (#FF00FF), completely blank, no shadows, no floor, no gradients`.
   - Magenta (`RGB 255, 0, 255`) rarely collides with character palettes and provides maximum contrast for automated segmentation.
3. **ALWAYS provide an existing asset reference path**:
   - Reference an existing character sprite or concept image.
   - Instruct the `image-generator` subagent to include the reference path in its `ImagePaths` parameter. This locks down character anatomy, costume, color palette, and pixel density.
4. **Request HORIZONTAL sprite sheets rather than single frames**:
   - Requesting an animation sequence on a single horizontal strip forces the model to maintain character proportions, styling, and scale consistently across all frames in a single context window, eliminating frame-to-frame drift.

---

## Slicing & Post-Processing Tool

Generated images are usually JPEG/WebP with slight compression artifacts around high-contrast edges. The included post-processing script:
- Samples the chroma key background color dynamically.
- Eliminates compression fringing/halos by dilating the background mask and clamping edge pixels into crisp dark outlines.
- Detects bounding boxes for all animation frames.
- Centers and bottom-aligns each frame onto a standardized transparent canvas (default: `301x288` px, matching standard pixel sprite viewports).

### Run Command

```bash
uv run --with pillow --with numpy --with scipy python ~/.agents/skills/nano-banana-sprites/scripts/slice_spritesheet.py <generated_image> --out <output_dir> --width 301 --height 288
```

Parameters:
- `input`: Path to the generated spritesheet image.
- `--out` / `-o`: Destination directory for sliced frames (e.g., `assets/sprites/walk/` or `.dumps/frames`).
- `--width` / `-W`: Target canvas width (default: `301`).
- `--height` / `-H`: Target canvas height (default: `288`).
- `--min-size` / `-m`: Minimum width/height in pixels for bounding box detection (default: `40`).

---

## Complete End-to-End Autonomous Workflow

Any AI agent can execute this complete sequence directly via bash:

### 1. Identify or Select Reference Asset
Locate an existing asset to anchor character consistency:
```bash
REF_ASSET="/path/to/existing/character_reference.png"
```

### 2. Invoke Headless `agy`
Run `agy` in non-interactive batch mode (`-p`) with `--dangerously-skip-permissions` to allow automated file writes:

```bash
agy -p "Please use the image-generator subagent to generate a 16-bit retro pixel art sprite sheet of a 4-frame walk animation sequence on a horizontal strip.
Reference image: ${REF_ASSET} (pass this in ImagePaths to lock down character design, costume, hair, and color palette).
Style: Crisp retro game pixel art, sharp pixel edges, distinct pixel grid, flat colors, no anti-aliasing blur.
Background: Solid pure uniform chroma key magenta background (#FF00FF), completely blank, no shadows, no ground, no floor.
Save the generated image to .dumps/sprites/walk_sheet.jpg and return the exact path." --dangerously-skip-permissions
```

### 3. Slice and De-Fringe Frames into Transparent PNGs
Once `agy` outputs the generated image file:

```bash
uv run --with pillow --with numpy --with scipy python ~/.agents/skills/nano-banana-sprites/scripts/slice_spritesheet.py \
  .dumps/sprites/walk_sheet.jpg \
  --out assets/sprites/character/walk/ \
  --width 301 \
  --height 288
```

### 4. Verify Exported Frames
```bash
ls -la assets/sprites/character/walk/
```
The output directory will contain cleanly cut, transparent PNG frames (`00.png`, `01.png`, `02.png`, etc.) ready for immediate use in game engines or UI components.
