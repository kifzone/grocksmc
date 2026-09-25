# Architecture audit — Quantum SMC Intelligence Engine

Audit date: 2026-09-25. Baseline: `c3758d4418555e65c821f280cd17b8be6e85155c`.

## Scope and identity

Read all 3,784 lines **before editing source**. The repository contains only
`QuantumSMC_AI_Pro_v5.6.9_COMPACT_DASHBOARD.mq5`, not `KLJ.mq5`.
No includes, tests, data, build scripts, causal ledger, predictive dataset or
MetaTrader compiler were supplied. Preserve the original entry point.
The filename says 5.6.9; header says 5.4.0/5.4.1; properties and UI say 5.7.0.
Historical repair notes are not proof of correctness.

The exhaustive function → function/global-state map (110 definitions), enum,
structure and global inventory is in [docs/BASELINE_DEPENDENCIES.md](docs/BASELINE_DEPENDENCIES.md).

## Actual dependency architecture

```
OnInit → 3 plot buffers; EMA/ATR/ADX/RSI/5 MTF EMA handles; mutable collections
OnCalculate → chronological price copy → EMA/VWAP
  ├─ full: clear detectors → structure → OB/breakers → zones → FVG → liquidity
  ├─ incremental: maintain zones/liquidity → tail scans → structure continuation
  └─ context: dealing range → D1/HTF bias → Judas → kill zones
       → array pruning → price/strength/priority indexes → bit mask
       → undirected proximity graph → weighted/knapsack/DP setup scoring
       → candidate zone/SL/targets → READY → RETEST → CONFIRMED → retirement
       → dashboard / chart objects / alerts
OnChartEvent → reposition panel or force next-bar path
OnDeinit → release handles / remove objects (some signal arrows survive)
```

- `BufEmaFast`, `BufEmaSlow`, `BufVWAP`: chronological plots; not primary triggers.
- Structure continuation: last confirmed high/low, direction, displacement latch,
  last scanned index. One swing scale; no protected-swing hierarchy.
- OB/setup UIDs are useful, but liquidity/FVG and graph nodes lack causal IDs.
- Blacklist has exact IDs plus expiring fuzzy price/direction entries.
- The graph links nearby prices in **both directions**. No timestamps or ancestry;
  **not a causal graph**. Keep it only as a legacy confluence heuristic.
- Full rebuild reconstructs final detector arrays, NOT historical setup decisions.
  It retains setup/blacklist state and executes the decision engine only once.
- MTF panel is EMA direction at five configurable periods, not synchronized
  structural MTF intelligence. Defaults MN1/W1/D1/H4/H1, not D1/H4/H1/M15/M5.
- D1/HTF “bias” derives from discount/premium in a fixed extrema window; it is a
  mean-reversion context heuristic, not independently confirmed directional bias.

## Findings before changes

| ID | Severity | Finding / causal failure |
|---|---|---|
| C01 | Critical | `DetectZones` reads `atr[total-1]` for a historical zone; forming/future ATR changes historical acceptance and a short buffer can overrun. |
| C02 | Critical | Structure/zones/FVG accept short `CopyBuffer` results, treating oldest returned sample as bar zero. |
| C03 | High | `DetectOrderBlocks` uses latest `g_atr` on every historical OB and live wick for TOUCHED; both alter scores. Mitigation starts before OB is known. |
| C04 | Critical | Structure displacement persists across direction changes: a previous move can label a later weak reversal MSS. |
| C05 | Critical | Setup is backdated to structure origin; lifecycle can confirm using the creation/pre-creation candle. Live close can permanently invalidate it. |
| C06 | High | Liquidity needs a right-confirmed fractal but dates equal-pool detection before confirmation, uses current ATR for all historical tolerances and full/incremental sweep windows differ. |
| C07 | High | Swept pool is not marked consumed; repeat sweeps and targets can reuse it. `swept` conflates event and pool state. |
| C08 | High | FVG merging rewrites geometry/time ancestry and replays old fills against new geometry. With merge OFF, tail rescans duplicate FVGs. |
| C09 | Critical | HTF APIs use shifts relative to present, not historical decision time; forming D1 extrema enter targets. Not usable for replay. |
| C10 | High | Sessions and scoring use `TimeCurrent`, not event time; server timezone/DST is implicit, overnight sessions unsupported. |
| C11 | High | Full rebuild and incremental differ in caps, scan windows, mitigation, blacklist, and setup history. Timestamp-persistent arrows are NOT reproducibility proof. |
| C12 | High | `CalculateProbability` is an arbitrary weighted score with bonuses, displayed as percent; no calibration/outcomes exist. |
| C13 | High | Failed indicator reads leave stale ATR/ADX/HTF caches; cache keys can commit before copy succeeds. |
| C14 | High | Targets prefer already swept liquidity and can skip nearer pools. ATR fallback TPs may be non-monotonic; no minimum RR gate. |
| C15 | High | Zone fallback synthesizes price-centred regions, widens structural zones and can qualify without sweep/MSS. Not evidence of institutional activity. |
| C16 | Medium | Full VWAP reset overwrites prior sessions with closes, so historical plots change on daily rollover. |
| C17 | Medium | Price arrays assume time/open/high/etc share series flags. No input validation. Fractal/tail/array settings can be inconsistent. |
| C18 | Medium | Context/mask can score opposite-direction or stale OB/sweep; all events lack availability/dependency validation. |
| C19 | Medium | Signal markers lack timeframe/config identity, survive parameter changes, and can visually imply reproducible history. |
| C20 | Medium | Custom chart event fakes a new bar; lifecycle mutates on every tick; cleanup before invalidation leaves stale trade objects until next tick. |

## Duplication, dead code, incomplete claims

- `BinarySearchNearestOB`, `SafeVal`, `DrawLevelText`, `AddOrMergeFVG_Simple` have no
  callers; retain pending compatibility decisions, do not market their existence.
- Knapsack and DP confidence are the same 0/1 recurrence with different capacities;
  their output is scored again in probability → correlated/double-counted evidence.
- FVG mitigation is implemented in detection and `ReevaluateFVGState`; OB/zone/
  breaker touch logic is duplicated in full and incremental branches.
- `InpUseBitMasking`, `InpRealTimeFractal`, `InpSmartTargets` do not control their
  advertised algorithms. `InpMinRightConfirmBars` is printed but not used for confirmation.
- Graph `visited`, zone `strength_score`, OB distance/age and several cached state
  fields are unused or not maintained as their names imply.
- No regime state machine, recursive scenarios, analog search, prediction freeze,
  outcome matching, walk-forward, Monte Carlo or statistical edge validation exists.
- No PWH/PWL engine, IFVG, volume imbalance, formal mitigation/rejection blocks,
  causal session transitions, high-impact-calendar risk gate or normalized evidence ledger.

## Preservation and development boundary

Preserve chronological arrays, confirmed fractals, stable IDs, separate index
sorts, D1/H4 context, liquidity/displacement/structure/OB/FVG concepts, PD/OTE,
EMA/VWAP filters and tracked setup lifecycle. Correct causality before extending
prediction. Do not bolt a toy Python predictor onto a non-replayable indicator.

This delivery is **Phase 1 plus a bounded Phase 2 correctness increment**, not
completion of the 12-phase programme. Later phases remain gated by actual MQL5
compilation and a single prefix-replay transition shared by all detectors.
See CHANGELOG and VALIDATION_REPORT for precisely implemented fixes and limits.

## Complexity (baseline and retained algorithms)

For B bars, bounded collections K, fractal radius F: structure O(B·F) plus ATR
copy O(B); OB/zone/FVG lifetime scans can be O(B·K) and historical creation can
be O(B²). Liquidity nested scans are bounded by 40/15 but use a full lookback;
index insertion sorts O(K²); proximity graph O(K²) with 14-node cap. Knapsack
O(factors·capacity). VWAP full O(B), incremental O(new bars). No performance
claims until correctness tests exist. Do not optimize away availability checks.
