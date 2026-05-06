# Art Bible — Auto Game Builder Dashboard

Source of truth for the AGB control-room mobile app's visual identity. Scope is the dashboard itself (screens, widgets, theme) — *not* the games it manages. Each managed game has its own art-bible.md under its own project.

All values live in `app/lib/theme.dart`. If you change a color or radius in one place, change it here too.

---

## 1. Identity in One Line

A late-night control room: deep navy panels, cards lit by a single coral accent, every status earning its own vivid pill. Calm field, loud signal.

The dashboard is a *tool*, not a game. It should feel reliable and unhurried. Color is reserved for state — never decoration.

---

## 2. Palette (current — dark-only)

### Surfaces
| Token | Hex | Use |
|---|---|---|
| `bgDark` | `#1A1A2E` | Scaffold background, screen body |
| `bgSidebar` | `#16213E` | App bar, bottom nav, drawer |
| `bgCard` | `#0F3460` | Cards, chips, snackbars |

Three navies stacked, each one step lighter than the last. Reads as elevation without needing shadows.

### Brand
| Token | Hex | Use |
|---|---|---|
| `accent` | `#E94560` | Primary action, FAB, focused inputs, selected chips |

The coral is the only warm color in the palette. Use it sparingly — one accent per screen is the rule. If two things are coral, neither one feels primary.

### Semantic
| Token | Hex | Meaning |
|---|---|---|
| `success` | `#2ECC71` | Done, published, completed |
| `warning` | `#F39C12` | Pending, fixing, attention-needed |
| `error` | `#E74C3C` | Failed, crashed, blocked |
| `info` | `#3498DB` | Building, in-progress, neutral status |

---

## 3. Status Colors (the "pill" system)

Every state gets a unique color. The phone is glanceable — a user shouldn't have to read text to know if a build is running, queued, or failed.

### App lifecycle (`AppColors.statusColor`)
| Status | Color | Hex |
|---|---|---|
| idle | grey | — |
| queued | amber | `#F1C40F` |
| building | info blue | `#3498DB` |
| uploading | purple | `#9B59B6` |
| working | teal | `#1ABC9C` |
| fixing | warning orange | `#F39C12` |
| deploying | info blue | `#3498DB` |
| error | red | `#E74C3C` |
| published | green | `#2ECC71` |

### Task status (`AppColors.taskStatusColor`)
| Status | Color | Hex |
|---|---|---|
| pending | orange | `#F39C12` |
| in_progress | blue | `#3498DB` |
| completed | green | `#2ECC71` |
| **built** | **purple** | **`#9B59B6`** |
| failed | red | `#E74C3C` |
| divided | blue | `#3498DB` |

The purple **built** badge is signature — it marks tasks that shipped in a real build, distinct from "completed but not yet bundled." Don't reassign that purple to anything else.

### Task type (`AppColors.taskTypeColor`)
| Type | Color | Hex |
|---|---|---|
| issue | orange | `#F39C12` |
| bug | red | `#E74C3C` |
| fix | blue | `#3498DB` |
| feature | green | `#2ECC71` |
| idea | lilac | `#AB47BC` |

### Agent (`AppColors.agentColor`)
| Agent | Color |
|---|---|
| claude | coral (`accent`) |
| gemini | blue (`info`) |
| codex | green (`success`) |
| local | orange (`warning`) |

### Priority (`AppColors.priorityColor` / `priorityLabel`)
1 Critical → red · 2 High → orange · 3 Medium → yellow · 4 Low → blue · 5 Wishlist → grey

---

## 4. Shape & Spacing

| Element | Radius | Notes |
|---|---|---|
| Cards | 12 px | `RoundedRectangleBorder` |
| Inputs | 8 px | `OutlineInputBorder` |
| Chips | 8 px | |
| Snackbar | 8 px | Floating behavior |
| Card elevation | 2 | M3 elevation; no custom shadows |

Material 3 is on (`useMaterial3: true`). Don't add custom shadows or gradients — let M3 elevation do the work.

---

## 5. Typography

System default — Roboto on Android, SF on iOS. No custom font shipped, no Google Fonts dependency.

If a custom font is ever added, it goes here first (this doc), then `pubspec.yaml`, then `theme.dart`.

Hierarchy:
- **App bar / screen titles**: M3 `titleLarge`
- **Card headers**: M3 `titleMedium`, white
- **Body**: M3 `bodyMedium`, white87 on dark bgs
- **Status labels in pills**: `bodySmall`, white, semibold

---

## 6. Iconography

Material Icons only — no custom icon set. App-type icons are mapped in `AppColors.appTypeIcon`:

| Type | Icon |
|---|---|
| flutter | `phone_android` |
| godot | `games` |
| python | `terminal` |
| web | `web` |
| phaser | `sports_esports` |

App launcher icon: `app_icon.ico` (Windows) + Flutter-generated mobile variants. Style: flat, single-color, dashboard motif. When updating, regenerate all densities — never ship a single-density icon.

---

## 7. Brand & Voice

- Parent brand: **Life Charger** (all apps use `com.lifecharger.*` package).
- Dashboard tone: terse, technical, no marketing fluff. Status text is verbs ("Building," "Fixing," "Uploading"), never adjectives ("Awesome!").
- No emoji in UI strings. No exclamation points except in legitimate error toasts.

---

## 8. Dark / Light Mode (planned)

Currently the theme is hardcoded `Brightness.dark` with literal hex constants. To support light mode without breaking the existing screens, the migration goes in this order:

1. **Tokenize first.** Every widget that calls `AppColors.bgDark`, `bgSidebar`, `bgCard` directly must be replaced with `Theme.of(context).colorScheme.surface` / `surfaceContainer` / `surfaceContainerHigh`. This is mechanical but unavoidable — literal references can't respond to a theme switch.
2. **Define both schemes.** Add `buildDarkTheme()` and `buildLightTheme()` in `theme.dart`, both using the same `accent` (`#E94560`) but different surfaces. Light surfaces: `#FFFFFF` / `#F5F5F7` / `#E8EAF0` — three steps of elevation, just inverted.
3. **Audit semantic colors.** Status pills need a contrast pass for light mode. Orange `#F39C12` and yellow `#F1C40F` will read poorly on white — bump saturation or darken ~10%. Run them through WCAG AA.
4. **`ThemeMode` toggle in settings.** Three options: System / Dark / Light. Persist to Hive (`syncMeta` box, key `theme_mode`). Default to System.
5. **Test the screen with the most colored chrome first** — `app_detail_screen.dart` and the dashboard cards. If those look right in both modes, the rest will follow.

Rules that must hold across both modes:
- Coral `#E94560` stays the only accent in either mode.
- Status colors keep their *meaning* — green = success, red = error, purple = built. Hue may shift slightly for contrast; meaning never does.
- The "one coral per screen" rule applies in light mode too.

Anti-patterns to avoid:
- A "midnight" or "AMOLED black" mode. Stay with `#1A1A2E` — the navy is the brand.
- Per-screen theme overrides. The whole app switches together; no exceptions.
- Sepia / solarized / "fun" modes until dark+light ships cleanly.

---

## 9. Components

### Card
- Background: `colorScheme.surfaceContainer` (current: `bgCard`)
- Radius: 12 px
- Padding: 16 px
- Elevation: 2

### Pill / status badge
- Pill = colored background + white text
- Padding: 8 px horizontal, 4 px vertical
- Radius: 12 px (full pill)
- Color = the relevant status / task / agent color from §3

### FAB
- Background: `accent`, foreground white
- Single FAB per screen. If you need two actions, use a bottom sheet.

### Snackbar
- Floating behavior, 8 px radius
- Background: `bgCard`
- White text — no colored snackbars

### Bottom nav
- Background: `bgSidebar`
- Selected: `accent`
- Unselected: grey

---

## 10. Update Discipline

When `theme.dart` changes:
1. Update §2 / §3 tables in this file.
2. If a status / task type is added, update §3 *and* the relevant `switch` in `theme.dart`.
3. If light mode lands, replace §8 with the as-built spec.

This document is canon. If a screen disagrees with this file, the screen is wrong.
