# Brief: push ONE in-development game closer to production (2026-09-25)

User: "go into animashift, pixel adventurer and ant empire, use PixelLab if needed to improve them,
get them closer to production." Nothing in the tasklist is open; you decide what matters most.

## 1. Audit first (write it down before changing anything)
Read the game's CLAUDE.md / AGENTS.md, gdd.md and design/*.md (the design doc named in the game's
section below is the CURRENT concept - older docs in legacy/ are not). Then list, by severity:
- What a first-time player sees that is not production quality: placeholder art (coloured boxes,
  default Flutter icons, programmer text, missing animations/static sprites where motion belongs,
  missing SFX/music), empty screens, broken flows, crashes, layout overflow on 360x640 / 412x915.
- Core loop gaps vs the design doc (features stubbed, TODOs, dead buttons).
- Retention/monetisation pieces the design doc asks for (daily reward, progression, rewarded ads,
  IAP) - wire only what the doc asks for; never invent a monetisation scheme.
- Store readiness: icon, feature graphic, screenshots, listing text, privacy policy matches the real
  SDKs, analytics client present (lib/**/lifecharger_analytics.dart), crash-free startup.
Save the audit as `design/production_audit_2026-09-25.md` in the game.

## 2. Then fix, biggest player-facing gap first
- ART: use the PixelLab MCP tools (create_character / animate_character / create_map_object /
  create_ui_asset / create_topdown_tileset / create_image_pro etc., mcp__pixellab__*). Match the
  game's art-bible.md. Budget: at most ~900 PixelLab generations for your game (3 games share
  ~3,600 this cycle). Generate, download, place under the game's assets/ with the existing naming,
  and wire them in code. Check every asset by looking at it (Read the PNG) before wiring it.
  CLAUDE.md rules: never ship a coloured rectangle, default icon or static sprite where an
  animation belongs - generate it. No fallback art presented as done.
- CODE: finish half-built features the design doc describes, fix bugs, fix layout overflows.
  Keep the game's own patterns and naming. Keep it iOS-portable.
- Adult figures only, never minors / chibi-child proportions (house rule).
- No Firebase / Sentry / paid telemetry. No new ad networks.

## 3. Hard rules
- NO builds, NO deploys, NO git commits, NO emulator/device, NO GUI input / exe launching.
- Edit only inside your game's folder (and download PixelLab output into it).
- Keep `flutter analyze` free of new errors/warnings and the game's full `flutter test` green
  (C:/flutter/bin/flutter). Add tests where the game already tests the code you touch.
- Track the work in the game's tasklist.json: one task per meaningful change, int id = max+1,
  status "completed" when done, titles say what the game now does (positive wording, no mention of
  deploys/production). Do not set "built".
- If you run low on context, stop at a clean point and report what is left.

## 4. Report (short)
Audit headline (top 5 gaps), what you fixed (file paths, assets made + generation count), what is
still missing for production and your recommended next steps, test results (counts).
