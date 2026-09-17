# Character extraction edge modes

The accepted clip version's `wan.json` may set `edge_refinement` to `soft`
(default) or `strict`. Character Flow passes this per-clip option to the SAM
extractor. Existing clips keep their current output behavior.

`soft` retains the established minimum edge-alpha floor. `strict` caps alpha
by the ISNet matte in the SAM boundary band, without changing the interior
SAM mask. This is useful for flat-background sprites whose background colors
remain visible in soft edge pixels. Strict mode requires the ISNet model and
ONNX Runtime; unavailable refinement is an error rather than a silent downgrade.

The extractor records `edge_mode` and actual per-frame methods in `sprite.json`.
An enabled `refine` flag alone does not prove a matte was available. Inspect
the exported edges and frame continuity before accepting any animation.

All extraction/model work must be invoked through live AGB Character Flow and
its shared GPU lane. Direct CLI execution does not provide queue ownership.
