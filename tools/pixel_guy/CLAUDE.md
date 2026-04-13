# Pixel Guy - Claude Code Instructions

## Project Overview
- Flutter idle life sim RPG
- Package: `com.lifecharger.pixelguy`

## Conventions

### Global Rules
- Prices must ALWAYS be dynamically loaded — NEVER hardcode prices
- All apps are for mobile phones. Design, test, and optimize for mobile. Touch-friendly UI, responsive layouts, portrait mode unless specified otherwise.
- If a store/IAP system exists, prices must come from the platform (Google Play Billing, App Store, etc.)
- If price not yet loaded, show a loading indicator — NOT a dollar amount
- All apps/games must have a bottom navigation bar for screen navigation. Never rely on only back buttons or header menus.
- Always account for Android system navigation bar (bottom bar/gesture area). Use SafeArea, padding.bottom, or MediaQuery.of(context).padding.bottom to prevent UI elements from being hidden behind the system nav bar.

### NEVER Use Placeholders
- NEVER use placeholder art, placeholder images, placeholder icons, colored rectangles, or TODO comments for visual assets
- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT:
  - Use PixelLab MCP tools if available (create_character, topdown_tilesets, tiles_pro, create_map_object, etc.)
  - Use Python scripts in Auto Game Builder's `tools/pixellab/` and `tools/grok/`: pixellab_generate_image.py, pixellab_generate_background.py, pixellab_generate_ui.py, grok_generate_image.py
- If you cannot generate the asset (no credits, rate limited, tool error), mark the task as "failed" — do NOT substitute a placeholder
- This rule applies to ALL assets: icons, sprites, backgrounds, UI elements, buttons, textures, tiles
- NEVER use animation fallbacks (static sprites, single-frame "animations", or skipping animations). If a task needs an animation, GENERATE IT using PixelLab MCP (animate_character) or SDK tools. If generation fails, mark the task as "failed".

### Flutter Conventions
- Flutter path: `/c/flutter/bin/flutter`
- Build AAB: `export PATH="/c/flutter/bin:$PATH" && cd "/c/Projects/Auto Game Builder/tools/pixel_guy" && flutter build appbundle --release`
- Always run `flutter analyze` after changes
- Use test ads during development, production ads only in release
- All signing keys in `D:/keys/`

### Testing
- When a test task is assigned, build debug APK, install on emulator via mobile MCP, and test all screens and core gameplay.
- For each problem found (crash, layout issue, missing element, broken navigation, off-screen content), create a separate new task in tasklist.json with a clear description.
- If everything works fine, report "All tests passed" with no new tasks created.
- IGNORE on emulator: dynamic price loading, Google Play Billing, Google sign-in, cloud save, IAP functionality. These only work on real devices.


## CRITICAL: No Fallback Policy
- NEVER use fallback/placeholder logic as an excuse to skip work
- If an asset is missing, GENERATE it — do not show a colored rectangle, default icon, or "fallback sprite"
- If an animation is missing, GENERATE it — do not use a static sprite as "good enough"
- If a feature is partially implemented, COMPLETE it — do not mark it done with a TODO comment
- "Fallback exists" does NOT mean the task is complete. The fallback is for runtime safety only, not a substitute for proper implementation
- If you cannot generate an asset (no API credits, tool error), mark the task as FAILED with the reason — do NOT substitute a placeholder
- Every sprite should have its proper animations. Every screen should have its proper assets. Every sound should play its proper file.
- Static sprites where animations should exist = INCOMPLETE WORK
- Colored rectangles where sprites should exist = INCOMPLETE WORK
- Try-catch that swallows errors silently = HIDING PROBLEMS

