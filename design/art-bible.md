I have enough context from the server code to write a complete art bible. The platform manages pixel-art mobile games with PixelLab/Godot/Flutter tooling. Writing the art bible now.

---

# Art Bible — Auto Game Builder Mobile Games

*Version 1.0 — Source of truth for all asset generation (PixelLab, Grok, ElevenLabs, Meshy)*

---

## 1. Visual Identity Statement

**Warm pixel art adventure — vibrant, readable, joyful on a 5-inch screen.** When any art call is ambiguous, choose clarity over complexity, warmth over coolness, and character over realism.

Supporting principles:
- **Readable at thumb-distance.** Every sprite, icon, and tile must read as a distinct silhouette at 1× display size. If you need to squint, it fails.
- **Colour tells the story.** Game state, character role, rarity tier, and danger level communicate through palette alone — before the player reads a single label.
- **Pixel craft, not pixel retro.** Clean, deliberate pixel placement. Not NES-era noise. Not smooth-interpolated blur. Every pixel is intentional.

---

## 2. Mood & Atmosphere by Game State

| State | Primary Emotion | Lighting Character | AI Style Note |
|---|---|---|---|
| **Explore / Overworld** | Wonder, safety | Warm afternoon sun, 5500 K, soft shadows, high ambient | `top-down pixel art, warm sunlit village, soft shadows, inviting, golden hour` |
| **Combat / Encounter** | Tension, urgency | High contrast, 4000 K cool-warm split, rim-lit characters, pulsing vignette | `pixel art battle scene, dramatic contrast, red-orange enemy, cool blue hero, dynamic` |
| **Menu / Hub** | Calm confidence | Dark starfield backdrop, candlelit UI panels, medium contrast | `pixel art menu screen, deep navy background, warm gold UI panels, stars, cozy` |
| **Victory** | Elation, reward | Burst of white → gold, full saturation spike, particle bloom | `pixel art victory, golden light burst, confetti particles, bright saturated, triumphant` |
| **Defeat / Game Over** | Tension, retry urge | Desaturated, 15% saturation, cool grey-blue tint, dim vignette | `pixel art defeat screen, desaturated, faded, grey-blue, solemn, retry prompt` |

---

## 3. Color Palette

### Core Colors (backbone of every scene)

| Role | Name | Hex |
|---|---|---|
| Deep background | Midnight Navy | `#1A1A2E` |
| Ground / terrain | Rich Earth | `#5C3D2E` |
| Nature / foliage | Forest Green | `#3D6B45` |
| Architecture / stone | Slate Grey | `#8B9DA5` |
| Light / highlight | Warm Cream | `#F0E6C8` |

### Accent Colors (used for secondary elements, UI chrome)

| Role | Name | Hex |
|---|---|---|
| Rewards / XP / gold UI | Hero Gold | `#FFD166` |
| Enemies / danger / errors | Danger Crimson | `#EF476F` |
| Water / magic / sky | Horizon Blue | `#4CC9F0` |
| Fire / energy / hot VFX | Ember Orange | `#F4845F` |
| Healing / success / nature magic | Life Green | `#6BCB77` |

### Signature Colors (reserved — rare moments only)

| Role | Name | Hex |
|---|---|---|
| Legendary / rare tier | Arcane Violet | `#9B5DE5` |
| Boss encounter / critical moment | Inferno Red | `#FF6B35` |
| Victory fanfare / final reward | Trophy Gold | `#FFC300` |

**Palette rules:**
- Never introduce an out-of-palette colour without a deliberate reason documented in a task.
- On-screen UI must use only core + accent colours; signature colours appear only at the moment they name.
- Dark backgrounds must be `#1A1A2E` or a 10–20% lighter tint of it — never pure `#000000`.

---

## 4. Character Art Direction

**Silhouette rule:** Every character silhouette must be recognisable in a 16×16 greyscale thumbnail. If the outline alone doesn't tell hero from enemy from NPC, redesign the silhouette.

**Proportion system:**
- Base sprite canvas: 32×32 px (enemies) or 48×48 px (hero, bosses)
- Head-to-body ratio: 1:3 (slightly large head, mild stylisation — not chibi, not realistic)
- Limbs: stubby but distinct; exaggerated action poses during animation

**Line weight:**
- 1 px hard black outline on all characters at base resolution
- No anti-aliased edges — ever
- Inner detail lines are 1 px, same palette colour darkened 40%

**Shading approach:**
- Cel shading with exactly **2 tone levels**: flat fill + 1 shadow value (base colour darkened 30%), no mid-tone gradients
- 1–2 highlight pixels in `#F0E6C8` tint on the topmost visible surface
- No dithering on character sprites (reserved for environment textures only)

**Default idle stance:** Front-facing, arms slightly out from body, weight on both feet, 2-frame breathing cycle (frame 1: neutral, frame 2: +1px height shift on torso)

**Rejected styles:**
- Anime large-eye proportions
- Photorealistic muscle/skin shading
- Traced-photo outlines
- Pure 1:4 adult proportions (too stiff for mobile)

---

## 5. Environment & Level Art

**Perspective:** Top-down orthographic (45° tile grid). Godot TileMap system.

**Tile system:**
- Tile size: **16×16 px** base (rendered 2× → 32×32 on screen at standard DPI)
- Texel density: 16 px per in-game metre
- Tileset atlas: 256×256 px per atlas sheet; max 16×16 tiles per sheet
- Dithering allowed on terrain edges only (2-pixel dither strip at biome boundaries)

**Scale conventions:**
- Player character occupies ~2×2 tiles at default zoom
- Doorways: minimum 2-tile width
- Interactive objects (chests, signs): 1×1 or 1×2 tile, centred within tile grid

**Background / skybox treatment:**
- Overworld background: scrolling parallax, 3 layers (`#1A1A2E` sky → silhouette mountains in `#2D3B5A` → mid-ground trees in `#3D6B45`)
- Interior: solid `#2A1E15` dark wood ceiling at 8 px top strip; no visible sky
- No photographic backgrounds. No gradient mesh fills — use flat banded gradients max 4 steps.

**Lighting pass:** Global illumination is baked into tile art. Dynamic lighting (torches, spells) uses additive sprite overlays at 40% opacity using palette colours — never white bloom.

---

## 6. UI Visual Language

**Button shape:** Rounded rectangle, `border-radius` equivalent = 6 px at 1× scale. 3 px drop shadow in a darkened version of the button colour (`-30%` lightness). Minimum touch target: 48×48 dp (Flutter) / 44×44 pt (Godot screen-space).

**Border style:** 2 px solid inner border, lighter tint of background colour (+20% lightness). Outer edge: 1 px hard shadow line.

**Font family:**
- Primary: **Pixelify Sans** (Google Fonts — pixel-style) at 8, 12, 16, 24 px steps only
- Fallback: **Nunito** (round, friendly, legible at small sizes)
- NO italic text in-game (pixel fonts don't anti-alias; italics become unreadable)

**Icon style:** 16×16 px pixel icons for in-game HUD; 32×32 px for menus. Single-colour with 1-shade fill, matching the palette role (e.g., health = `#6BCB77`, currency = `#FFD166`). All icons ship with transparent background.

**Panel treatment:**
- Main panels: `#1A1A2E` fill, `#FFD166` 2 px top border, 6 px corner radius
- Tooltip panels: `#2D2D4A` fill, 1 px `#8B9DA5` border
- Scrollable lists: no visible border, inner shadow only

**Color-role mapping for UI states:**

| State | Colour |
|---|---|
| Primary action / CTA | `#FFD166` (Hero Gold) |
| Destructive / delete | `#EF476F` (Danger Crimson) |
| Success / confirm | `#6BCB77` (Life Green) |
| Warning / caution | `#F4845F` (Ember Orange) |
| Disabled | `#8B9DA5` at 50% opacity |
| Selected / focused | 2 px `#4CC9F0` outline |

---

## 7. VFX & Particle Style

**Particle count budget:**
- Hit/impact: max 12 particles
- Explosion/death: max 24 particles
- Level-up / reward burst: max 40 particles (screen-space, one-shot)
- Ambient (campfire, water): max 8 particles per emitter; max 3 simultaneous emitters

**Shape language:** Round soft circles (4–6 px diameter at 1×) for magic and healing; sharp 2×2 squares for physical hits and dirt; 1 px sparks for fire/electricity. No complex mesh particles.

**Color rules:**
- All particles must use palette hex values — no arbitrary colours
- Hit particles: use the attacker's colour theme (enemy = `#EF476F`, player = `#4CC9F0`)
- Healing: `#6BCB77` → fade to `#F0E6C8`
- Fire: `#FF6B35` → `#FFD166` → `#F0E6C8` (hottest to coolest)
- Coin/XP: `#FFD166` with `#FFC300` core

**Timing:**
- Hit flash: 0.08 s white flash on sprite, then fade 0.12 s
- Impact burst: spawn all particles at 0, fade out over 0.3–0.4 s
- Level-up burst: 0.6 s full cycle; particles arc outward then gravity-fall
- Ambient: 1.5–3 s looping, staggered spawn
- No slow-dissolve lingering effects beyond 0.6 s — mobile GPU budget

---

## 8. Asset Standards

### Sprite Resolutions

| Asset Class | Canvas Size | Export |
|---|---|---|
| Hero sprite (all frames) | 48×48 px per frame | PNG RGBA, no background |
| Enemy sprites | 32×32 px per frame | PNG RGBA, no background |
| Boss sprites | 64×64 px per frame | PNG RGBA, no background |
| NPC / prop | 16×16 or 32×32 px | PNG RGBA, no background |
| Tileset atlas | 256×256 px | PNG RGBA |
| UI icons (HUD) | 16×16 px | PNG RGBA, no background |
| UI icons (menu) | 32×32 px | PNG RGBA, no background |
| App icon / launcher | 1024×1024 px | PNG, solid background |
| Background / parallax layer | 512×512 px (tiling) or 480×852 px (portrait full-screen) | PNG RGB |
| Splash screen | 1080×1920 px | PNG RGB |

### Audio Formats

| Use | Format | Bitrate |
|---|---|---|
| Sound effects (short) | `.ogg` Vorbis | 96 kbps |
| Music / ambient loops | `.ogg` Vorbis | 128 kbps |
| Voice / narration | `.ogg` Vorbis | 128 kbps |

**No `.mp3` in Godot projects** (patent/licensing edge cases in some regions). Use `.ogg` exclusively.

### Atlas & Texture Rules

- All character animations must be packed into a **single spritesheet** per character (horizontal strip, left-to-right frame order)
- Frame order convention: `idle (4f) → walk (6f) → attack (5f) → hurt (2f) → death (6f)`
- Max spritesheet width: 512 px; wrap to next row if exceeded
- Compression: no lossy compression on sprites. Lossless PNG only.
- All sprites require **transparent background** (no magenta/white fill as transparency key)
- Export at 1× base resolution; scaling is handled at runtime (Godot: `filter = false` on all pixel art textures)

---

## 9. Style Prohibitions

These are hard rejections. An asset matching any item below gets regenerated.

**Visual style:**
- No photorealism or photographic textures
- No 3D renders passed off as 2D art (exception: Meshy-generated 3D models for dedicated 3D scenes)
- No smooth gradient meshes or radial gradients on character/tile art
- No neon cyberpunk palette (`#00FFFF`, `#FF00FF` against black)
- No muddy, unsaturated brown-grey colour schemes
- No semi-transparency / alpha < 80% on character outlines (causes ghosting at pixel scale)

**Character style:**
- No anime large-eye proportions (iris height > 40% of face height)
- No hyper-realistic muscle anatomy
- No Western cartoon rubber-hose limbs (Fleischer style)
- No clipart-style thick outlines > 2 px at base resolution

**UI style:**
- No bevelled/embossed 3D button effects (skeuomorphic)
- No drop shadows with blur radius > 4 px
- No white text on yellow or gold backgrounds
- No font sizes below 8 px (pixel font) or 10 dp (vector font)
- No more than 3 font sizes on a single screen

**Technical:**
- No anti-aliased pixel art sprites (set Godot import filter = off / nearest-neighbour)
- No placeholder grey boxes, colour fills, or "TODO: add sprite here" comments
- No lorem ipsum text in any shipped screen
- No hardcoded price strings in UI — always load from Play Store/App Store billing at runtime

---

*Identity summary: Warm pixel art, top-down, portrait mobile. Palette anchored to Midnight Navy `#1A1A2E` + Hero Gold `#FFD166` + Danger Crimson `#EF476F`. Every asset ships at exact canvas size with transparent background, no anti-aliasing, and palette-only colours.*