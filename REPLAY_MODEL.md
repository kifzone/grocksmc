# Replay model

## Baseline vs current implementation

The indicator's “full rebuild” is an endpoint reconstruction of selected arrays,
not bar-by-bar historical issuance. It cannot reconstruct previous setups,
blacklists, predictions or outcomes. This fundamental limitation is **not fixed**
by using closed bars in individual detectors.

## IMPLEMENTED verification

`tools/native_runner.py` extracts **16 production function bodies** directly from
the indicator and adapts only array syntax for C++17 execution. The fixture shim
provides bounds-checked arrays, synthetic ATR/broker values and no-op chart/log
APIs. Function algorithms are not reimplemented in Python.

Covered paths:

- structure scanner/fractals/OB-origin search;
- OB/zone/FVG creation and supporting dedup/breaker/strength-index routines;
- setup lifecycle;
- EMA/VWAP function, with EMA APIs stubbed and a separate VWAP oracle.

Prefix replay compares structure events and persistent trend/high/low state over
2,058 prefixes (six seeded synthetic series). Canonical event serialization includes
all structure fields, not only event counts; exact equality is stronger than hash
equality for these small fixtures. VWAP compares historical values across multiple
days, full reconstruction, incremental processing and repeated ticks.

Future mutation freezes structure evidence through bar 500, changes OHLCV/fixture
ATR at 501+, and compares both the prefix call and a longer full scan. The known
next-bar open timestamp is held fixed (it defines the historical availability).
Independent fixtures mutate forming ATR/wicks and test OB/zone invariance.

## What this does NOT establish

- MQL5 syntax/type correctness or binary equivalence to C++;
- actual `CopyBuffer`, series, indicator handle readiness or MT5 scheduling;
- broker calendar / HTF history synchronization;
- complete OnCalculate full/incremental parity, capped-array retention or blacklist;
- a causal graph, MarketState hash, scenario hash or prediction/outcome hash;
- real market profitability or stability.

## Required next implementation

Create one `ProcessClosedBar(as_of, data_view, state)` transition. Full replay resets
**all** state and invokes that transition for each chronological prefix. Incremental
updates invoke the same transition for missing bars. Data views must enforce each
stream's close/availability, including weekends/gaps and broker session calendars.
Historical ATR/ADX/spread must be prefix-aligned; no live symbol API in replay.

At each prefix: observe prior frozen outcomes → update causal events/zones → build
MarketState → generate scenarios → freeze new predictions → export canonical
records. Never evaluate the issuing candle as subsequent outcome data. Use bounded
active state plus durable event/prediction records, rather than discarding ancestry
through display limits. History corrections need an explicit revision/run identity,
not silent editing of an earlier prediction.

Only after this exists can full-vs-incremental and future-mutation tests compare all
five requested domains: graph, MarketState, setup, scenarios and prediction ledger.
