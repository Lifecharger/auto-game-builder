# GDD Standard Template — 8 Required Sections

When enhancing or generating a Game/App Design Document, ensure these 8 sections exist:

## 1. Overview
One-paragraph summary: what is this game/app, who is it for, what platform, what genre.

## 2. Player Fantasy / User Value
What does the player FEEL while playing? What problem does the app solve?
- Core emotion: power, discovery, relaxation, creativity, competition
- Reference games/apps that capture a similar feeling
- The "elevator pitch" — one sentence that sells the experience

## 3. Core Loop / Core Flow
The repeating cycle that defines the experience:
- For games: Play → Reward → Upgrade → Play (with specifics)
- For apps: Trigger → Action → Result → Track
- Diagram the loop with clear entry/exit points
- Session length target (how long is one satisfying loop?)

## 4. Detailed Mechanics / Features
Unambiguous rules for every system:
- Controls and input mapping
- State machines for game states
- Screen-by-screen feature breakdown for apps
- Interaction rules between systems

## 5. Formulas & Data
All math defined with variables:
- Damage = base_attack * multiplier - defense
- XP curve: level_xp = base_xp * (level ^ growth_factor)
- Economy rates: earn_rate, spend_sinks, inflation_controls
- All values reference a config/data file, never hardcoded

## 6. Edge Cases & Error Handling
Unusual situations explicitly handled:
- What happens at 0 resources / max level / empty inventory?
- Network failure during transactions
- First-time user with no data
- Interrupted sessions (phone call, app switch)
- Rapid input / double-tap prevention

## 7. Dependencies & Technical Notes
- Required systems/plugins/APIs
- Platform-specific considerations
- Third-party services (analytics, ads, IAP, cloud save)
- Asset requirements (art style, audio, animations)

## 8. Monetization & Retention
- Revenue model: free, paid, freemium, ad-supported
- IAP catalog if applicable
- Ad placements (rewarded, interstitial) — frequency and triggers
- Retention mechanics: daily rewards, streaks, notifications
- Analytics events to track: session_start, level_complete, purchase, churn_risk

## Acceptance Criteria
Testable conditions that prove the game/app works:
- [ ] Core loop is playable end-to-end
- [ ] All screens navigable
- [ ] Economy balanced for 7-day retention
- [ ] Builds successfully on target platform
- [ ] No crashes in 30-minute playtest
