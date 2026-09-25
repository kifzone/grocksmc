# Changelog

## 5.7.1 — 2026-09-25 — causal correctness increment (not production-certified)

Preserved the repository's original indicator filename and principal architecture.
Full baseline audit was written before source modification.

| Change | Architectural reason | Verification |
|---|---|---|
| Exact-length historical ATR copies; decision failure guard | Prevent shifted data indexing and stale decisions | Selected structure/OB/zone/FVG short-copy tests; integration lint only |
| Reset ATR/ADX; commit HTF memo keys only on success | Failed reads must not masquerade as current evidence | Source check; terminal runtime NOT RUN |
| Zone uses event ATR; OB uses break ATR | Future/forming volatility cannot rewrite historical acceptance | Executed zone/OB future-ATR fixture |
| OB lifecycle starts after break; no live scored touch | A zone cannot retest before it is known | Executed OB availability/live-wick fixture |
| Reset displacement per candidate | Unrelated old impulse cannot establish new MSS | Executed current-break MSS test; negative mutation control |
| Structure swing/confirmation/availability metadata and rejection | Preserve actual confirmed parent timing | 1,138 synthetic events, 112 MSS chronology/evidence checks |
| Separate setup structure origin from creation availability | Prevent backdated retests/confirmations | Executed lifecycle fixture and negative control |
| Closed-only lifecycle, no live distance invalidation | Tick sequence must not change historical state | Executed tick immutability test |
| Immediate retirement validity clear; post-transition cleanup | Avoid displaying retired valid signals | Lifecycle test; rendering needs MT5 |
| Immutable FVG geometry + origin dedup | Evidence merging rewrites historical fill semantics | Merge on/off fixtures, negative control |
| Remove unused unsafe `AddOrMergeFVG_Simple` | No callers; duplicated geometry-mutation path | Declaration/call lint |
| Session scoring uses closed event time | Wall-clock hour cannot score an earlier event | Source check; timezone/DST still incomplete |
| Remove forming-D1 targets | Current day's extrema are not closed context | Source check |
| Rename heuristic probability output | No calibrated dataset supports probabilities | Source check and explicit dashboard status |
| Daily historical VWAP reconstruction | Rollover must not replace past VWAP with closes | Independent oracle, full/incremental and repeated-tick tests |
| Independent array series flags + input guards | Avoid implicit ordering and invalid-window assumptions | Source check; MQL runtime NOT RUN |
| Remove signal arrows on reinit, include TF in names | Old config arrows are not replay proof | Source check |
| Custom chart events redraw only | Presentation event must not replay lifecycle | Source check |

### Compatibility / deliberate behavior changes

- Retest is no longer a live tick transition. It requires a subsequent closed bar.
- Setup timeout starts at actual seeding, not an older structure origin.
- FVG merge input is retained for presets but no longer merges **evidence** records;
  OnInit explains this. Display clustering is not implemented.
- Signal arrows move to confirmation availability and do not survive reinitialization.
- Dashboard/alerts no longer label heuristic scores as probabilities.
- Required-data failures suppress decisions instead of silently using partial context.
- Fixed pip/synthetic fallback policies, score arithmetic and most legacy detectors
  remain; this is not yet the final institutional entry model.

### Acceptance

PASS only for the scoped tests documented in VALIDATION_REPORT. Whole-engine
acceptance is BLOCKED. No EX5, real market dataset or statistical performance claim.
