# Puzzle-line coin economy evaluation

Date: 2026-09-14. Scope: current local source for Hot Jigsaw, Pro Jigsaw, Hot Slider and Hot Charm. This is an evaluation, not a balance change. Installed/store versions and actual player earning rates were not measured. Cash prices were not fetched from Google Play; comparisons below concern coin purchasing power, not currency value or conversion revenue.

Subsequent owner decision (2026-09-14): retain the generous gameplay economy and ticket prices; increase all four paid coin packs tenfold to 1,000 / 5,000 / 12,000 / 30,000 coins across the four games. The implementation below the audit date supersedes the original paid-pack comparisons: solo/Surprise Pro Jigsaw now excludes hint-placed pieces proportionally from completion coins, preserving rewards for manual pieces. Normal solve rewards and daily claims remain unchanged. The audit below records the original findings rather than the updated pack quantities.

Implementation records: Hot Jigsaw #266, Pro Jigsaw #239 (packs) and #237 (solo hint rewards), Hot Slider #148, Hot Charm #163. Validation: 132 targeted tests passed across the four apps; final analysis returned zero errors/warnings with two pre-existing informational deprecations per app. Local source changes only; store metadata and released applications were not changed. Co-op retains its separate reward policy.

## Verdict

The ordinary first-clear rewards are generous and understandable against a 100-coin collection picture. The larger problem is that login rewards and assistance weaken the reasons to earn or buy coins. Pro Jigsaw also has a potentially repeatable hint-funded completion loop. Preserve rewarding play; address assistance and replay accounting before reducing normal rewards.

## What coins buy

These prices are shared by all four apps unless noted.

| Purchase | Coin price | Effective unit price |
|---|---:|---:|
| Collection picture | 100 | 100 |
| Ad-free tickets | 1 / 5 / 10 for 100 / 450 / 800 | 100 / 90 / 80 |
| Auto-complete items | 1 / 3 / 5 for 150 / 400 / 600 | 150 / 133.33 / 120 |
| Hints, except Hot Slider | 5 / 15 / 40 for 25 / 65 / 150 | 5 / 4.33 / 3.75 |
| Individual hint, except Hot Slider | 5 | 5 |
| Pro Jigsaw premium color preset | 150 | Permanent cosmetic |

Tickets substitute for supported ad actions; they should not be counted as discounted collection purchases. In Hot Jigsaw's unlock dialog, generic content offers ad/ticket choices while collection content offers coins. The collection screen also offers random unlocks at 100 coins.

All four start with 500 coins. All four sell packs granting 100, 500, 1,200 and 3,000 coins. These buy 1, 5, 12 and 30 collection pictures respectively. VIP and the lifetime collection pass are distinct: VIP provides ad removal, generic access and daily benefits; the collection pass grants current/future collection content. A pass owner therefore loses the main content coin sink.

Sources: each app's `lib/utils/constants.dart`, `lib/models/user_progress.dart`, `lib/screens/shop_screen.dart`; Pro Jigsaw `lib/widgets/shop/shop_consumables_section.dart` and `lib/services/puzzle_appearance_service.dart`; Hot Jigsaw `lib/widgets/puzzle_unlock_dialog.dart`.

## Rewards versus purchases

Base manual first-clear rewards, excluding modifiers, daily bonuses and achievements:

| Game | Representative board sizes → coins | Medium solves to fund a 100-coin picture, from zero |
|---|---|---:|
| Hot Jigsaw | ~16 → 15; 36 → 40; 49 → 70; 64 → 100; 100 → 150 | 2 at 49 pieces |
| Pro Jigsaw | 25 → 40; 50 → 80; 100 → 200; 200 → 320; 300 → 480; 500 → 720; 1,000 → 1,120; 1,500 → 1,600 | 1 at 100 pieces, funds 2 pictures |
| Hot Slider | 8 → 15; 15 → 40; 24 → 70; 35 → 110; 48 → 150 movable tiles | 2 at 24 tiles |
| Hot Charm | 12 → 20; 36 → 50; 49 → 65; 64 → 95; 100 → 140; 121 → 170; 144 → 200 tiles | 2 at 49 tiles |

Hot Jigsaw maps actual rectangular boards to the nearest configured tier. Pro Jigsaw uses piece-count thresholds, so reward jumps occur at 41, 56, 81, 131, 251, 401, 601 and 1,101 pieces. Slider interpolates and extrapolates past 48 movable tiles (55 pays 172); Charm interpolates but caps at 200 beyond 144 tiles. These are representative counts, not guarantees for every aspect-ratio-dependent grid.

If a player purchases one new collection picture per solve, base net coins at the representative medium level are -30 Hot Jigsaw, +100 Pro Jigsaw, -30 Hot Slider and -35 Hot Charm. At their 150/200-coin top anchors, the other three also become self-funding. That is reasonable for rewarding harder play; it is not evidence of a defect by itself. Pro Jigsaw's longer sessions need real completion-time data before judging its higher absolute rewards.

Jigsaw modifiers pay 1.5x / 2.5x / 4x / 6x for one through four active modifiers. Slider and Charm have two modifiers and top out at 2.5x. Thus 100-piece Hot Jigsaw can pay 900, 100-piece Pro Jigsaw 1,200, 48-tile Slider 375 and 144-tile Charm 500. These are conditional challenge payouts, not ordinary earnings. Pro Jigsaw co-op separately pays base × (1 + 0.25 × extra players), without dividing that award among players.

Sources: the two Jigsaw `assets/config/difficulty_config.json` files; all four `lib/utils/constants.dart` and `lib/models/game_state.dart` (Pro co-op: `awardCoopCompletion`).

## Daily income dominates the smaller purchases

| Game | Day 1–7 base claims | First seven days total | Day 7 daily base / doubled |
|---|---|---:|---:|
| Hot Jigsaw | 30, 60, 100, 150, 200, 250, 300 | 1,090 | 300 / 600 |
| Pro Jigsaw | 40, 70, 110, 150, 190, 240, 300 | 1,100 | 300 / 600 |
| Hot Slider | 50, 90, 130, 175, 220, 260, 300 | 1,225 | 300 / 600 |
| Hot Charm | 20, 40, 70, 110, 165, 225, 300 | 930 | 300 / 600 |

These ladders plateau; they do not reset to day 1 every week while the streak continues. Hot Jigsaw further rises to 350 from day 14 and 400 from day 30. A completed rewarded-ad bonus or VIP doubles the base. VIP also has a separate daily 50 coins plus three auto-complete items.

At day 7, login alone funds three pictures, or six with the doubler. For medium play this equals approximately 4.3 Hot Jigsaw solves, 1.5 Pro Jigsaw solves, 4.3 Slider solves or 4.6 Charm solves before doubling. The 100-coin cash pack therefore competes with one third of a mature free daily claim. The 3,000-coin pack equals ten such base claims, or five doubled claims. This makes coin packs weak time-savers for returning players even without knowing their cash prices.

Over 30 consecutive claims, excluding starter coins, play, achievements and VIP extras, base income is 8,890 / 8,000 / 8,125 / 7,830 respectively. That buys 88 / 80 / 81 / 78 whole pictures. Daily doubling doubles the coin totals.

Other sources amplify this: Hot Jigsaw pays a separate 50-coin daily-puzzle solve bonus; Hot Charm's Daily Charm adds a play-streak multiplier through its challenge path; Pro Jigsaw has a daily free-content selection. Achievement configuration totals are 23,325 coins, 213 tickets and 219 auto-completes in each Jigsaw, versus 22,775 coins, 208 tickets and 216 auto-completes in Slider/Charm. These are sums of configured entries, not guaranteed reachable payouts or monthly income. Redeem codes are additional externally determined grants.

Sources: each `lib/models/user_progress.dart`, daily services, and `assets/config/achievement_rewards.json`.

## Priority findings

1. **Pro Jigsaw: hints can finance their own replacement.** Hints automatically place pieces and trigger ordinary completion checking. Three modifiers without the timer (rotation, grayscale, no grid) give 4x. A 100-piece board therefore pays 800. Buying 100 hints costs 390 (40+40+15+5 hints for 150+150+65+25 coins), leaving 410 net on an already unlocked picture. Even 100 individually bought hints cost only 500, leaving 300. Replay pays full again. This is a source-confirmed economic path, not a device-executed exploit test. Relevant code: `lib/screens/puzzle_screen.dart:739`, `lib/widgets/puzzle_workspace.dart:633`, `lib/models/game_state.dart:383`, `:530`, and `lib/utils/constants.dart:162`. Track assisted placements and prevent fully assisted solves from earning challenge-scaled profit. The existing 15-coin auto-complete payout does not cover individual hints.

2. **Replay rules are inconsistent, and the reduced-reward games punish difficulty progression.** Both Jigsaws pay full manual rewards again. Slider and Charm pay 20% after a picture's first completion; the key is collection/image, not difficulty/modifiers. Completing an easy version first therefore reduces the later hard version to replay pay. Record comparison likewise spans the image rather than comparable difficulty. Preserve full first-clear rewards per difficulty/modifier configuration and evaluate repeat-play rewards separately. Do not blindly copy the current 20% rule to the Jigsaws. Charm's record bonus is 25% of modified reward; Slider's is 25% of unmodified base, another inconsistency.

3. **Daily claims overshadow play and coin packs.** Treat this as the main balance experiment after correctness fixes. Preserve the historically approved generous solve rewards. First try shifting part of the mature daily grant behind a genuine daily solve, or adding desirable optional permanent sinks. Any change to existing VIP promises needs separate product consideration. Suggested experiments are design proposals, not measured optimal values.

4. **Auto-complete pricing itself is safe from a direct buy/use loop.** All four pay a flat 15 after item use, compared with a minimum shop unit cost of 120. Net loss is at least 105 per purchased item, before content access costs. VIP's three free daily items are effectively 360 coins of bulk-shop substitute value plus up to 45 completion coins if used. They reduce repeat demand for this sink but are an intentional benefit.

5. **Pro Jigsaw still displays hardcoded cash-price fallbacks.** `lib/widgets/shop/shop_coins_section.dart:57` and `shop_vip_section.dart:196` contain dollar defaults when platform products are missing. These are not verified live prices and should be replaced with loading/unavailable states under the project pricing rule. The other games also use fixed percentage savings labels; their accuracy cannot be established without current regional platform prices.

## Recommended order and validation

First close the Pro Jigsaw hint-profit path. Next correct the first-clear/record identity in Slider and Charm, and explicitly choose the two Jigsaws' replay policy. Keep normal solve rewards and the 100-coin picture anchor for now. Then evaluate daily-claim changes and optional cosmetic sinks before enlarging coin packs or increasing content prices.

For a later balance trial, compare ordinary versus assisted coins per minute, daily-claim share of earned coins, purchases per active day, and balances for free, VIP and collection-pass owners. Use consented/local or existing approved reporting; no new telemetry service is required by this evaluation. Completion time assumptions would otherwise dominate any claim that one game's economy is objectively fairer.

Validation: ran each project's existing `flutter test --no-pub --concurrency=1 test/economy_test.dart`; all four suites passed. These tests verify current contracts, not monetization effectiveness, and do not cover the entire cross-system hint/replay issue described above. No application code or balance values were changed. AGB audit records: Hot Jigsaw #264, Pro Jigsaw #236, Hot Slider #146, Hot Charm #161.
