# Prediction model — implementation status and next contract

## IMPLEMENTED

The former `CalculateProbability` is now `CalculateEvidenceScore`. Its arithmetic
is retained to avoid an unrelated signal-threshold redesign, but output is marked
as a heuristic score out of 100, **not a calibrated percent probability**.
`InpMinProbability` is retained solely for saved-preset compatibility and is
commented as a heuristic score threshold. Dashboard explicitly displays:

```
Calibration: INSUFFICIENT DATA
Causal replay: NOT VALIDATED
```

## PARTIALLY IMPLEMENTED

Legacy weighted component breakdown, directional setup, structural/ATR candidate
targets and invalidation are retained. Their values lack per-component availability
and causal ancestry. Knapsack/DP double-counting, synthetic-zone fallback, RR gates,
and target ranking require further work before predictive use.

## NOT IMPLEMENTED

There is no unified `MarketState`, recursive scenario engine, frozen prediction
ledger, historical analog engine, outcome ledger or calibrated model. The scripts
`verify_predictive.py`, `verify_scenarios.py`, `verify_outcomes.py` report this and
exit **2 (BLOCKED)**; they are acceptance gates, not invented passing test suites.

## Planned contract (design only, not executable functionality)

1. Snapshot available D1/H4/H1/M15/M5 structural context, dealing range, regime,
   liquidity, sweep/displacement/MSS/zone/retest state and evidence provenance.
   Represent missing data explicitly, never as bearish/neutral evidence.
2. Hash a canonical snapshot including symbol, timeframe, parameters and schema
   version. Exclude future outcomes, render coordinates and mutable array indexes.
3. Create conditional bullish, bearish and no-trade branches with explicit required
   events, invalidating events, structural targets and invalidation. Bound recursion
   depth, branch count, minimum segment length and retained beam width. Prune on
   unavailable evidence/causal failure before scoring; memoize by state and horizon.
4. Freeze issuance once: prediction ID, snapshot hash, issuance availability,
   scenario/parent IDs, direction, reference price, structural target/invalidation,
   horizon and full evidence vector. Score != probability.
5. Analog selection uses only features available at historical issuance. Eligibility
   additionally requires analog outcome availability **before the new issuance**.
   Purge overlapping label horizons across chronological train/validation/test.
6. Return `INSUFFICIENT DATA` until predeclared sample counts, uncertainty bounds,
   out-of-sample calibration and regime/symbol coverage are met. Never normalize
   arbitrary branch scores into purported probabilities.
7. Outcome evaluation is independent of the frozen prediction. Record target hit,
   invalidated, partial, timeout, no signal or ambiguous; target and stop inside the
   same candle are ambiguous unless tick ordering is actually available.

Future-state scenarios are conditional hypotheses, not exact future-price forecasts.
No probability, expected return, hit rate or edge is asserted in this delivery.
