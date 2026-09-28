# Game UX baseline (every game, every agent, from the first line of UI)

These are not polish items and not QA findings - a screen that breaks one is not done.

## Layout
- Repeated items (cards, tiles, tree nodes, list rows, shop items, buttons in a row) share ONE fixed size in a strict grid. Never size an item by its own text; long text shrinks or ellipsizes inside the fixed box.
- Siblings in a row are equal height (and equal width in grids); icons, titles, values and prices sit on the same lines across repeated cards.
- Trees (talents, prestige, skills): uniform nodes, aligned tiers, connector lines, clear locked / available / maxed states.
- Nothing overflows, clips or overlaps at 360x640 and 412x915, at text scale 1.0 and 1.3. Safe areas respected (status bar, gesture bar, notch).
- Touch targets >= 48 dp; primary actions within thumb reach.

- Main screens FIT ON ONE SCREEN - no scrolling to reach the game's core actions (user 2026-09-27: "this is a game, scrolling menus is not nice"). The primary action (Play/Run) and key info are always visible; long content becomes compact summaries, tabs, pages or sheets. Only genuinely long lists (stash, codex, collections) may scroll, and they sit behind a tab/sheet, never on the home screen. A layout test asserts no scroll overflow on main screens at 360x640 and 412x915, text 1.0/1.3.

## Clarity
- The next useful action is always obvious (badge, glow, pointer); a new player understands the screen in seconds.
- Progressive disclosure: systems appear when they matter.
- Every number readable: compact formatting (1.2K, 3.4M), units stated, before -> after shown for upgrades.
- States are visible: disabled buttons look disabled and say why; empty states say what to do.
- Colour is never the only signal (icons/labels too); contrast readable on every background.

## Feel
- Every action answers: sound + visual feedback (press states, pops, count-ups, rarity colours, shake/flash on impact).
- Animation priority is logical (an attack plays through; hit reactions never lock a unit out of acting).
- Game rules match what is drawn: the player never dies to something they visibly cleared, never loses to an invisible rule.
- No dead time where input is ignored; buffer inputs during transitions.

## Proof (required before reporting done)
- An automatic layout/misalignment test: every screen and sheet at 360x640 and 412x915, text 1.0 and 1.3 - equal sibling sizes, aligned rows, no overflow/clipping, 48 dp targets.
- Render screenshots of every screen touched and LOOK at them; fix before reporting.
