# Grok Asset Pipeline — Game Character Generation Playbook

This doc is the **canonical workflow** for generating a game character + animation pack via the `grok_*.py` tools. It exists so I (Claude) stop asking the user the same questions every time. **Before generating any character asset, read this end-to-end.**

---

## The full pipeline at a glance

```
1. Generate SOUTH (front-facing) base   →   grok_generate_image.py --pro --aspect 1:1
2. Show user 4 candidates, let them pick   (or auto-pick most neutral pose)
3. PAD the chosen base horizontally     →   pad_image.py -i south.png -o south_padded.png --horizontal 0.5
4. i2i derive other directions             →   grok_i2i.py (padded south → east, west, north)
5. PAD each directional variant          →   pad_image.py --horizontal 0.5
6. Animate ONE direction first (test)    →   grok_animate.py (single animation on padded image)
7. User reviews → continue full pack     →   grok_animate.py × N animations
8. Downloader renames by prompt keywords →   grok_downloader.py auto-runs at end
```

**Order matters.** South first (front view shows the character clearest = best reference). Animate ONE before batching all 9 (so you catch problems before wasting credits).

### Why 1:1 base + pad, not 16:9 direct

**OLD approach** (`--aspect 16:9`): Grok generates the character filling the 16:9 frame. The character still hogs the horizontal space and sword swings clip out during animation. 9:16 is worse — zero horizontal room. 16:9 is better but still not enough.

**CURRENT approach** (`--aspect 1:1` + `pad_image.py --horizontal 0.5`): Grok generates the character in a natural square frame (it frames characters best at 1:1). Then `pad_image.py` adds 50% extra horizontal space using the auto-sampled background color, making the final base ~1.5:1 widescreen with the character occupying only the center ~60%. This **guarantees** room for sword swings, walk cycles, and attack arcs regardless of what Grok rendered.

**The padding is seamless** because it samples the background color from the image's four corners and extends it. For typical Grok "plain neutral grey studio background" outputs this looks invisible.

---

## Defaults — never deviate unless explicitly asked

| Parameter | Default | Why |
|---|---|---|
| **Aspect ratio (animatable bases)** | `--aspect 1:1` then `pad_image.py --horizontal 0.5` | Square gives Grok the best character framing. Padding adds horizontal breathing room with auto-sampled background color. **NEVER 9:16 portrait** — Grok crops too tight. 16:9 direct is also less reliable than 1:1+pad. |
| **Image quality mode** | `--pro` | Quality mode (4 images, follows prompts faithfully). Speed mode goes off-rails — only use it for non-character bulk gen where exactness doesn't matter. |
| **Video length** | 6s | Cheapest, fastest. The 10s option is rarely worth 2x credits. |
| **Video resolution** | 480p | Cheapest. Bump to 720p only when the user asks for "high quality" output. |
| **Animation count per character** | 9 | Idle, walk, run, jump, attack1, attack2, block, hurt, death. Standard side-scroller pack. |

---

## Sexy character baseline (so I don't keep asking)

When the user asks for a "sexy" character, the **tasteful baseline** is:

- **Top:** Fitted leather corset / armored top with **modest cleavage** (think Skyrim, Witcher, Diablo IV — not Red Sonja chainmail bikini)
- **Bottom:** Short pleated leather **miniskirt** (skirt covers important bits, exposes thighs)
- **Legs:** Bare thighs, **knee-high black leather boots** with buckles
- **Arms:** Often bare, with leather wrist bracers/gauntlets
- **Build:** Slim athletic with feminine curves, **normal proportions** — NOT exaggerated huge breasts, NOT hourglass cartoon
- **Face:** Beautiful, full lips, pointed elven ears (if elf), seductive but not anime
- **Hair:** Long flowing — platinum/silver/blonde for elves, vary for other races
- **Style direction:** Photorealistic fantasy art, "Frank Frazetta tier of tasteful" — sexy AF, not vulgar

**Only escalate beyond this baseline if the user explicitly says** "more revealing", "bikini armor", "bare midriff", etc. Default is the corset + miniskirt look.

**Only dial back below this baseline if the user explicitly says** "less sexy", "armored", "practical", etc.

---

## Animation prompt template — STATIC CAMERA RULES

For ALL i2v animation prompts, the camera language is **non-negotiable**. Grok defaults to cinematic camera moves which ruin sprite animations. Always include:

```
locked side profile view, completely static camera,
no camera movement no pan no zoom no follow,
character stays centered in frame
```

Animation-specific phrases use "in place" / "treadmill" framing:
- Walk: "walking forward in place like on a treadmill"
- Run: "sprinting in place, side scroller run cycle"
- Jump: "crouches then jumps straight up then lands"
- Attack: "performs sword slash attack" (the in-place is implicit)

The 9-animation standard set (use these prompts as starting points):

| # | Animation | Prompt skeleton |
|---|---|---|
| 1 | Idle | "idle breathing animation, standing in ready stance, subtle weight shift and chest breathing, weapon held loosely" |
| 2 | Walk | "walking forward at calm pace, treadmill walk in place, side scroller walk cycle, smooth gait" |
| 3 | Run | "sprinting at full speed, side scroller run cycle in place, knees high dynamic stride" |
| 4 | Jump | "crouches then jumps straight up high then lands, side scroller jump animation" |
| 5 | Attack 1 (light) | "performs single fast horizontal sword slash attack, cleaving motion left to right, side scroller combat" |
| 6 | Attack 2 (heavy) | "raises sword high overhead then powerful two-handed downward slam strike, side scroller heavy attack" |
| 7 | Block | "raises sword vertically to block incoming attack, defensive stance, slight bracing motion" |
| 8 | Hurt | "takes hit and recoils backward briefly then recovers, hurt damage reaction" |
| 9 | Death | "is mortally wounded, dramatic falling backward to the ground death animation, body collapses" |

Always append the static camera block to every prompt.

---

## Choosing the best from 4 candidates

When `grok_generate_image.py --pro` returns 4 images, **don't pick by visual appeal alone**. Pick by **animation suitability**:

- ✅ **Neutral standing pose** with sword at side or in ready stance — best for deriving via i2i
- ✅ **Plain background**, character clearly separated from background
- ✅ **Full body visible** head to toe, no cropping
- ✅ **Centered in frame** with empty space on both sides (room for sword swings)
- ✅ **Single character only** — Grok sometimes renders portraits + full body in one frame; reject those
- ❌ Avoid hero shots with extreme dynamic poses — they bake in motion that conflicts with derived animations
- ❌ Avoid flowing capes/cloaks — they complicate i2v rendering
- ❌ Avoid "double-image" artifacts (same character drawn twice in one frame)

The **neutral starting pose wins** even if a more dynamic candidate looks cooler. Tell the user the rationale if there's a tradeoff.

---

## i2i directional derivation

For 4-direction sprite sheets (top-down RPGs), derive from the south base:

```
"exact same character, identical face and [HAIR COLOR] hair,
identical [OUTFIT DESCRIPTION], identical [WEAPON],
perfect SIDE PROFILE view facing camera RIGHT (east facing),
full body visible from head to toe, neutral standing ready stance,
character centered in frame with generous empty space on both sides,
plain neutral grey studio background, photorealistic"
```

Swap `RIGHT (east facing)` for the other directions:
- **East** → "facing camera right (east facing)"
- **West** → "facing camera left (west facing)"
- **North** → "back view, character facing away from camera (north facing)"

**Identity-preserving phrases** to ALWAYS include:
- "exact same character"
- "identical face"
- "identical [outfit details, repeat them all]"
- "identical [weapon]"

Without these, Grok will generate a *different* character that just matches the description loosely. Character consistency depends on these literal repetitions.

---

## Test ONE before batching all 9

After generating the directional view (e.g. east), animate **ONE** test animation first (idle is the safest because it's subtle). Verify with the user:

- Does the character look right after animation?
- Does the camera stay static?
- Is the framing usable for sprites?

**Only after user confirms, batch the remaining 8 animations.** This catches prompt issues, framing issues, and rate-limiting issues before wasting credits on a broken set.

---

## Lessons learned (don't repeat)

- **Cookie consent banners** on grok.com appear in 3+ variants (OneTrust, data-cookie-banner, plus a popup with "Tümünü Reddet"). The animate/i2i scripts purge all of them on every run via a generic text-match selector.
- **Submit click silently fails** in headless React forms unless followed by `Ctrl+Enter` and then `form.requestSubmit()`. The animate/i2i scripts try all three strategies in order — never remove that fallback chain.
- **Stale Playwright profile state** can cause the form to silently fail across runs. Symptom: `upload-file` fires but `media/post/create` doesn't. Fix: delete `~/.grok-playwright` and re-run.
- **Rate limiting** kicks in after ~10 rapid submissions in a row. Add delays or split batches.
- **Auto-favoriting is automatic** when you submit i2i or i2v — Grok auto-likes the input + result. The downloader picks them up because it filters on `MEDIA_POST_SOURCE_LIKED`.
- **Output goes to** `C:/Users/caca_/Downloads/grok-favorites/` as the canonical destination. Don't try to capture URLs from the WebSocket stream — the downloader handles it.
- **Aspect ratio is preserved** by i2v. A 9:16 input → 9:16 video (= cropped sword swings). A 16:9 input → 16:9 video (= room to move). This is the #1 mistake to never repeat.
- **Background Playwright runs get SIGTERM'd (exit 143)** by the Claude harness watchdog after a few minutes. Always run animate/i2i tools in **foreground** (no `run_in_background: true`). For long batches, structure as a single foreground bash chain — the entire chain counts as one foreground command. The downloader is fine in background since it's short.

---

## Time + cost budgeting

- **Image gen (--pro):** ~30s for 4 images
- **i2i:** ~30s submit + ~30-60s render + auto-download
- **i2v (6s/480p):** ~30s submit + ~60-120s render + auto-download
- **Full 9-animation pack:** ~12-15 minutes wall-clock with sequential submission

When running batches, use `--no-download` on individual calls and run `grok_downloader.py --since-hours 1` once at the end. Saves 9× the download overhead.
