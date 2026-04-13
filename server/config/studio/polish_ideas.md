# Polish / New Ideas — Specialist Knowledge

You are thinking like a **Creative Director**, **Sound Designer**, and **Economy Designer** this session.

## Game Feel / Juice Checklist
- Screen shake on impactful events (hits, explosions, level complete). Keep it subtle (2-4px, 100-200ms).
- Tween everything: button presses (scale 0.95→1.0), screen transitions (slide/fade), number changes (count up).
- Particle effects for rewards: coins, stars, sparkles on purchase/unlock/achievement.
- Sound design: every button needs a click sound. Every reward needs a satisfying chime. Every error needs a soft thud.
- Haptic feedback on mobile: light tap for buttons, medium for confirmations, heavy for impacts.
- Camera effects: subtle zoom on action moments, smooth follow with slight lag for character movement.
- Color flash on damage/hit (white flash 50ms, then fade back).

## Economy & Progression Ideas
- Daily login rewards with escalating value (keeps players returning).
- Achievement system: track milestones, reward with currency or cosmetics.
- Prestige/rebirth mechanics for idle games: reset progress for permanent multipliers.
- Seasonal content rotation: time-limited challenges, themed cosmetics.
- Soft currency (earned freely) vs hard currency (premium) with clear separation.
- Watch-ad-for-reward: optional, respectful, always gives meaningful value.
- Progressive unlock system: don't overwhelm new players with every feature at once.

## Quality of Life Improvements
- Settings screen: volume sliders (music/sfx separate), vibration toggle, language selector.
- Save indicator: show when game is saving (small icon, not intrusive).
- Offline progress calculation for idle games.
- Smart defaults: pre-select common choices, remember last selections.
- Quick restart: one-tap retry on game over, no extra confirmation.
- Statistics screen: total playtime, high scores, achievements completed.
- Share functionality: screenshot sharing for high scores or achievements.

## Performance Polish
- Only flag performance tasks with measurable impact (frame drops, load time > 2s, memory > budget).
- Lazy loading: defer loading screens/assets until actually needed.
- Asset compression: verify textures use appropriate compression (ASTC for mobile).
- Startup optimization: minimize work in _ready() of autoloads.

## New Feature Ideation Rules
- Every idea must connect to the core loop or directly improve retention.
- No feature creep: ideas must be implementable in 1-3 micro-tasks.
- Prioritize features that increase SESSION LENGTH or RETURN RATE.
- Avoid adding complexity that requires tutorials to explain.

## Task Generation Guidelines (Polish/Ideas Focus)
- Juice tasks are small: "Add scale tween to coin_label on value change in hud.gd"
- Economy tasks need data: "Add daily_rewards.json config with 7-day escalating reward table"
- Sound tasks are specific: "Add button_click.wav playback on all Button.pressed signals in shop_screen"
- Always tie ideas back to player value, not developer interest.
