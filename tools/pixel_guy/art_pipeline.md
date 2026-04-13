# Art Pipeline - Pixel Guy

## Workflow
1. Generate video on Grok (grok.com)
2. Download MP4 to your Downloads folder
3. Run extract + rembg script → transparent PNG frames
4. Add to Flutter app

## Processing Script
```
python extract_all.py --chars-dir ./assets/characters --downloads-dir ~/Downloads
```
Or extract a single video:
```
python extract_single.py --input path/to/video.mp4 --output ./out
```
- Uses BiRefNet (u2net fallback) with CUDA GPU
- Set `PIXEL_GUY_PYTHON` to a CUDA-enabled python interpreter if needed
- ~90 seconds per 241-frame video
- Output: `assets/characters/char_{N}_anim/frame_XXX.png`

## Working Prompts & Grok Links

### Realistic - Blow Kiss
- **Link**: https://grok.com/imagine/post/808a024c-d331-4ffb-8677-ecdd9085bc0b
- **Prompt**: Photorealistic female elf standing still blowing a kiss with one hand, fixed camera, no camera movement, no zoom, static shot, front facing, full body from head to high heels visible, fantasy leather armor, solid dark background, smooth animation

### Realistic - Idle (template)
- **Prompt**: Wide angle full length portrait, photorealistic female elf standing on visible floor, entire body from top of head to high heel boots, subtle idle breathing, slight hair movement in breeze, fantasy leather armor, centered in frame, front facing, soft studio lighting, solid dark background, seamless loop

### Anime - Idle (template)
- **Prompt**: Wide angle full length portrait, anime style girl standing on visible floor, entire body from head to high heel boots visible, gentle idle breathing and hair flowing, cel-shaded clean lineart, fantasy elf outfit, centered in frame, front facing, solid dark background, seamless idle loop

### Pixel Art - Idle (template)
- **Prompt**: Wide shot pixel art character standing on visible floor, entire body from top of head to high heels, subtle idle breathing cycle, retro 16-bit RPG style, female elf adventurer, centered in frame, front facing, solid black background, seamless loop, leave space above head and below feet

### Cartoon - Idle (template)
- **Prompt**: Wide shot cartoon style character standing on visible floor, full body from head to high heels visible, subtle idle breathing and sway, bold outlines, vibrant colors, female elf adventurer, centered in frame, front facing, solid dark background, seamless loop

## Prompt Tips
- **Full body**: "wide shot", "standing on visible floor", "high heels visible", "leave space above head and below feet"
- **No camera move**: "fixed camera, no camera movement, no zoom, static shot"
- **Clean rembg**: "solid dark background" or "solid black background"
- **Looping**: "seamless loop"
- **Animation**: describe the specific action clearly

## Character Index

| ID | Style | Animation | Grok Link | Notes |
|----|-------|-----------|-----------|-------|
| 8 | Realistic | Turnaround | - | Redhead Elf |
| 9 | Realistic | Turnaround | - | Blonde Warrior |
| 10 | Realistic | Turnaround | - | Blonde Lace |
| 60 | Realistic | Static only | - | Forest Elf (back-facing) |
| 500 | ? | Idle | - | Style test |
| 501 | ? | Idle | - | Style test |
| 502 | ? | Idle | - | Style test |
| 503 | ? | Idle | - | Style test |
| 504 | ? | Idle | - | Style test |

## Art Style: PHOTOREALISTIC

## Animation Types Needed
- [ ] Idle (breathing loop)
- [ ] Walk cycle
- [ ] Attack / slash
- [x] Blow kiss
- [ ] Take damage / hurt
- [ ] Death
- [ ] Cast spell
