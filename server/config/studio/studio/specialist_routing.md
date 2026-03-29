# Specialist Routing — Task Type to Expert Knowledge

## Route by Task Type
| Task Type | Primary Expertise | Focus |
|-----------|------------------|-------|
| bug / fix | Lead Programmer + QA | Root cause analysis, minimal surgical fix |
| feature | Game Designer + Gameplay Programmer | Design-first, then implement |
| idea | Creative Director + Game Designer | Player value, feasibility, scope |
| issue | QA Tester + Gameplay Programmer | Reproduce, diagnose, fix |
| visual | Art Director + Technical Artist | Visual consistency, asset quality |
| audio | Sound Designer | Audio events, mixing, feedback |
| balance | Systems Designer + Economy Designer | Math, curves, data-driven tuning |
| perf | Performance Analyst + Engine Programmer | Profile first, optimize measured bottlenecks |
| ux | UX Designer | Player flow, accessibility, mobile patterns |
| narrative | Narrative Director + Writer | Story coherence, dialogue, world-building |

## Route by File Pattern
| File Pattern | Expertise |
|-------------|-----------|
| `*.gd`, `scripts/` | GDScript Specialist — typed GDScript, signals, coroutines |
| `*.tscn`, `*.tres` | Godot Specialist — scene composition, resources |
| `*.dart`, `lib/` | Flutter/Dart — widget composition, state management |
| `*.gdshader`, `shaders/` | Shader Specialist — visual effects, performance |
| `assets/`, `sprites/`, `textures/` | Technical Artist — asset pipeline, formats |
| `data/`, `config/`, `*.json` | Systems Designer — data-driven design, balance |
| `ui/`, `screens/`, `menus/` | UI Programmer + UX Designer — layout, interaction |
| `audio/`, `*.wav`, `*.ogg` | Sound Designer — audio events, mixing |
| `test/`, `tests/` | QA Lead — test coverage, regression |

## Route by Keyword in Task Description
| Keywords | Add This Context |
|----------|-----------------|
| "crash", "null", "error", "exception" | Code Safety: check is_instance_valid, null guards, await safety |
| "slow", "lag", "fps", "memory" | Performance: profile first, cache references, pool objects |
| "ugly", "misaligned", "overflow", "clipped" | Visual: pixel alignment, z-order, viewport fit, theme consistency |
| "confusing", "stuck", "lost", "unclear" | UX: navigation clarity, affordances, feedback, onboarding |
| "boring", "repetitive", "no reason to" | Game Design: core loop strength, progression, variety, reward pacing |
| "price", "cost", "reward", "currency", "shop" | Economy: data-driven values, sink/faucet balance, monetization ethics |
| "sound", "music", "audio", "silent" | Audio: event coverage, mixing levels, feedback completeness |
