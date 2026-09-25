# Causal model

## IMPLEMENTED in the Phase 2 increment

Arrays are chronological: zero is oldest, `total-2` is the last closed candle,
`total-1` is forming. Each input array's series flag is respected independently.

### Structure availability

A pivot at `f` with radius `N` is confirmed by closed bar `f+N`. Its conservative
bar-model availability is `t[f+N+1]`, the next observed bar open. A break at `i`
is permitted only when that parent is already available at `t[i]`.

Existing `SStructureBreak` now includes:

- `time`: break candle open (event origin);
- `confirmation_time = availability_time = t[i+1]`;
- `swing_origin`, `swing_confirmation_bar`, `swing_availability_time`;
- `displacement_atr`: the **current** break's measured move divided by its ATR.

Runtime guards reject unavailable swing parents and non-increasing event/close
clocks. This is a local structure chronology contract, **not a complete ledger**.
MSS requires current-break displacement; the old persistent latch cannot supply
it. This does not yet require a linked sweep or prove institutional activity.
Next-bar time is a bar-replay convention, not a measured tick delivery timestamp.

### Zones and setup availability

- Historical zone acceptance uses ATR at the zone event, not forming-bar ATR.
- OB geometry uses ATR at its structure break. Touch/mitigation begins **after**
  the structure candle. Live wicks cannot mutate scored OB state.
- FVG detector records retain original geometry and origin identity. Evidence
  merges are disabled even when the legacy `InpMergeFVG` preset is true. A future
  display-only cluster layer must not overwrite these records.
- Setup `structure_time` identifies its idea; `created_time` is actual creation
  availability. A setup cannot retest/confirm/invalidate on or before its seed
  candle. Lifecycle transitions are closed-bar only; forming OHLC is not evidence.
- Confirmation time is the next bar open. Arrows use that availability, not a
  retrospectively knowable candle open. Existing arrows are removed on reinit.

### Missing data

Full ATR copies must return exactly `total` samples before historical indexing.
Required ATR/ADX/HTF copy failures set `g_data_ready=false`; scoring/lifecycle/
alerts are skipped and a rebuild is requested. ATR/ADX are cleared before refresh.
HTF cache keys commit only after successful copies and reset on full rebuild.
These integration guards are source-checked; MT5 asynchronous delivery remains
untested. Data failure is not an invitation to reuse stale evidence.

## PARTIALLY IMPLEMENTED

Confirmed fractal state, event metadata and setup timing are now testable. The
existing graph remains a capped **undirected price proximity** graph for legacy
confluence. It must not be used as causal ancestry or prediction evidence.

## NOT IMPLEMENTED — required ledger contract

All event kinds still need stable IDs keyed by symbol, timeframe, configuration,
origin and availability; confirmation/availability bars; multiple dependency IDs;
source/evidence; confidence semantics; append-only invalidation records. Every
append must validate:

```
event_time <= confirmation_time <= availability_time
each dependency.availability_time <= child.event_time
all dependencies exist; no cycles; no silent eviction of required ancestry
```

A liquidity pool, its consumption and its sweep observation must be distinct
records. A zone's historical creation record must remain immutable while its
lifecycle gets append-only observations. Display caps must not be ledger caps.
No state may use HTF OHLC with close availability after its decision timestamp.

## Remaining causal blockers

Liquidity full scans still backdate pool detection relative to fractal confirmation,
use endpoint ATR, and differ from incremental logic. Full rebuild does not replay
setup/blacklist history. HTF APIs are current-relative, not historical as-of.
Targets can still prefer swept pools; synthetic setup regions remain legacy logic.
Sessions are broker-clock only, not DST-safe. These prevent a global no-lookahead
claim, irrespective of selected-function tests passing.
