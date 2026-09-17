# Relationships redo log (user verdicts from the review board)

| when | girl | board item | source | verdict note | action |
|---|---|---|---|---|---|
| 2026-09-15 23:05 | ava | L3 loop | old L4 (red knit dress) | head turns more than 180 | re-render, motion: gentle sway + brief glance over shoulder, always facing camera |
| 2026-09-15 23:08 | ava | L1 loop | old L2 (cream blouse) | (none) hand blurs white during the wave | re-render, motion: hand on hip, gentle sway, small nod, hands slow |
| 2026-09-15 23:30 | ava | L2 loop, L6 still+loop, L7 still, L8 still+loop, L10 still | matte | white between hair/shoulder, near shoes, between thighs | matte rule v5 (edge-connected white + enclosed pockets); re-cut, no render |
| 2026-09-15 23:30 | ava | L7 loop | old L7 (bunny) | ears/hands out of frame + thigh white | re-render, motion keeps figure in frame; matte v5 |
| 2026-09-15 23:50 | all | every still + loop | matte v6 | white walled by white shirt, white through fishnet, thigh gaps | RVM (edges) min isnet (holes, every 4th frame interpolated) + edge-connected white + enclosed pockets; full re-cut, no render |
| 2026-09-16 00:35 | luna | L7 loop | old L7 (gamer) | arms go out of frame | re-render, arms close, figure in frame |
| 2026-09-16 00:50 | iris | L3 still (old L5 nurse) | outfit | the hat is wrong | new still: classic white nurse cap with red cross; portrait + loop follow (redo_level.py) |
| 2026-09-16 00:50 | lilith | L3 still + portrait (old L3) | outfit | lv3 and lv4 are the same | new outfit: burgundy velvet governess dress, gothic library scene; portrait + loop follow |
| 2026-09-16 00:50 | luna | L1 loop (old L2 hoodie) | matte | white between fingers | inspect after final matte; re-cut |
| 2026-09-16 00:50 | ava | L1/L3/L7 loops | render done | re-renders landed; matting now |
| 2026-09-16 01:20 | all | every still + loop | matte v7 | RVM dropped props (bunny ears in ava L7 loop) | isnet may ADD sure-figure regions RVM dropped; full re-cut; approved items re-uploaded after |
| 2026-09-16 01:10 | luna | L1 loop (old L2) | matte | hands got erased, white background | re-cut with props rule (matte v7) |
- 2026-09-16 08:10 chloe L9_loop (src L9): note 'Girl comes closer. Not static' -> loop re-render with calmer motion, queued after the MatAnyone test frees the GPU
- 2026-09-16 09:38 ALL portraits: regenerate at each frame's own aspect (user: 'do generation best per frame. and animate per frame too'); old 9:16 scenes in _redo/scenes_v1
- 2026-09-16 09:54 chloe L5_loop (src L4): 'abrupt scene change' -> re-render with calmer in-frame motion, then MatAnyone matte (chain_ma_redo)
- 2026-09-16 09:54 chloe L7_loop (src L7): 'doesnt fit to frame' -> re-render with calmer in-frame motion, then MatAnyone matte (chain_ma_redo)
- 2026-09-16 09:54 elara L5_loop (src base): 'no movement at all' -> re-render with calmer in-frame motion, then MatAnyone matte (chain_ma_redo)
- 2026-09-16 09:54 freya L7_loop (src L7): 'Out of frame' -> re-render with calmer in-frame motion, then MatAnyone matte (chain_ma_redo)
