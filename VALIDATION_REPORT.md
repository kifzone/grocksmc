# Validation report — 2026-09-25

## Verdict

**PARTIAL DELIVERY — Phase 1 audit and a bounded Phase 2 correctness increment.**
**NOT production-certified. The full requested acceptance suite does not pass.**

The existing source has been patched, not replaced. Phases 3–12 have deliberately
not been represented by toy implementations or unsupported PASS labels. The
remaining whole-engine causal/replay defects must be fixed before adding predictive
claims. No MetaTrader/MetaEditor/Wine or broker OHLC/tick dataset is available here.

## Reproducible commands

Python 3.11 and g++ (C++17, undefined-behavior sanitizer) were used:

```sh
python3 tools/verify_all.py --implemented-only    # exit 0: LIMITED regression suite
python3 tools/verify_mutation_guards.py            # exit 0: five bugs detected
python3 tools/verify_all.py                       # exit 2: full acceptance BLOCKED
python3 -m compileall -q tools                    # Python syntax only
```

Individual requested entry points:

```sh
python3 tools/verify_engine.py         # limited static + lifecycle/FVG tests
python3 tools/verify_causality.py      # structure chronology only
python3 tools/verify_no_lookahead.py   # selected future-mutation fixtures only
python3 tools/verify_replay.py         # structure and VWAP only
python3 tools/verify_predictive.py     # exit 2, NOT IMPLEMENTED
python3 tools/verify_scenarios.py      # exit 2, NOT IMPLEMENTED
python3 tools/verify_outcomes.py       # exit 2, NOT IMPLEMENTED
```

The last three scripts are explicit unmet acceptance gates, **not implemented
verification suites**. Running the aggregate without `--implemented-only` never
returns success while these requirements are missing. Temporary native builds
live outside Git and are deleted; research datasets/EX5/logs are ignored.

## Executed results

| Check | Result | Scope / evidence |
|---|---|---|
| Static source inventory | PASS (limited) | 109 unique definitions; 101 matched forward declarations; balanced delimiters; recognized call names and regression guards |
| MQL5 compile/type check | NOT RUN | No MetaEditor; source lint and C++ adaptation are NOT substitutes |
| Selected native function compilation | PASS | 16 extracted function bodies with explicit fixture adapter, g++ + UBSan |
| Structure event timing / swing parent availability | PASS | 1,138 events across 20 seeded 600-bar synthetic fixtures |
| MSS displacement provenance | PASS | 112 MSS, each has current-break move >= configured ATR threshold |
| Short ATR copy rejection | PASS (selected) | Structure does not advance; OB/zone/FVG do not append |
| Structure incremental vs full prefix | PASS (selected) | 2,058 prefixes across six synthetic sequences; exact serialized event/state equality |
| Future mutation through bar 500 | PASS (selected) | 10 seeds; OHLCV and ATR mutated from 501 onward; prefix and longer rebuild preserve earlier structure |
| Zone/OB live/future mutation | PASS (selected) | Historical ATR invariant; no pre-availability or live-wick OB touch |
| Setup lifecycle | PASS (selected) | No seed-bar confirmation; tick immutability; next-bar confirmation timestamp; immediate retirement validity clear |
| FVG identity/geometry | PASS (selected) | Duplicate origin rejected, overlapping later origin cannot rewrite first, merge flag on/off |
| Historical daily VWAP | PASS | Independent weighted-price oracle over multiple days; full/incremental and tick-cumulative parity |
| Regression negative controls | PASS | Tests reject live-distance, stale-displacement, future-ATR, pre-availability-confirmation and FVG-identity mutants |
| Required-data/HTF cache integration | PARTIALLY IMPLEMENTED | Source guard checks; asynchronous terminal failure/retry runtime not tested |
| Git diff whitespace / Python syntax | PASS | Repository-local checks |

All fixture event counts are **test coverage**, not trades, market samples, hit
rates or statistical evidence. The native shim stubs broker/indicator APIs,
formatting and charts. It does not validate broker data ordering, full MQL typing,
actual ATR computation or object IDs produced by the formatter.

During test development, the original random-walk fixture failed its non-vacuous
MSS-count assertion (it generated no strong MSS). Explicit deterministic impulses
were added; production thresholds were NOT weakened. The initial adapter also
failed C++ compilation on MQL local struct-array syntax; that adapter conversion
was corrected. A later lifecycle fixture exposed leaked fixture ATR from the zone
test; setup fixtures now reset ATR and the mutant runner first requires an entirely
passing baseline. Those development failures are resolved, not concealed market
performance failures. Deliberate mutant assertion failures remain expected.

## Requested whole-system acceptance (honest gate status)

| Acceptance criterion | Status |
|---|---|
| Static integrity | PARTIALLY IMPLEMENTED — limited lint PASS; MQL compile NOT RUN |
| Causal graph integrity | NOT IMPLEMENTED — legacy graph is undirected proximity |
| No-lookahead guarantee | NOT ESTABLISHED — selected fixtures PASS; known liquidity/HTF/rebuild paths remain |
| Incremental replay | PARTIALLY IMPLEMENTED — structure/VWAP only |
| Full historical replay | NOT IMPLEMENTED — endpoint rebuild is not prediction replay |
| Runtime Liquidity → Sweep → Displacement → MSS → Zone → Retest chain | NOT IMPLEMENTED as auditable causal ancestry |
| Market state reconstruction | NOT IMPLEMENTED as unified synchronized MarketState |
| Scenario generation | NOT IMPLEMENTED |
| Scenario recursion / pruning | NOT IMPLEMENTED |
| Prediction ledger | NOT IMPLEMENTED |
| Historical outcome evaluation | NOT IMPLEMENTED |
| Walk-forward validation | NOT IMPLEMENTED; INSUFFICIENT DATA |
| Robustness / Monte Carlo | NOT IMPLEMENTED; INSUFFICIENT DATA |
| Calibrated probability / predictive edge | INSUFFICIENT DATA — no performance asserted |

**FAILED TEST:** none in the final limited regression run. **Unmet acceptance is
not PASS**: full acceptance intentionally returns exit 2 (BLOCKED). Runtime causal
correctness, whole-engine replay equality and predictive value remain unproven.

## Remaining phase gates

1. Complete Phase 2: causal liquidity availability/consumption; historical-as-of
   HTF alignment; full vs incremental retention/caps; rebuild setup/blacklist reset;
   target ranking/RR and same-candle ambiguity; structural evidence gates.
2. Phase 3: unified deterministic MarketState and explicit unknown/no-trade states.
3. Phase 4: protected hierarchical structure, quantitative displacement/sweep
   machine, zone/cluster lifecycles and synchronized MTF/session/regime context.
4. Phase 5: single chronological transition shared by full and incremental replay,
   causal event ledger and immutable issuance/export, with terminal parity tests.
5. Phases 6–8: bounded scenario recursion, frozen predictions/outcomes, past-only
   analog selection. Do not infer probability from arbitrary evidence weights.
6. Phases 9–10: purged chronological train/validation/test folds, held-out real
   symbols/regimes, random-entry/shuffle baselines and costs/delay/parameter/session
   perturbations. Report uncertainty and failures rather than fabricated edge.
7. Phases 11–12: evidence-aware dashboard/research view, then profile and optimize.
   Existing honesty labels are a correctness patch, not completion of Phase 11.

## MetaTrader verification required before deployment

On a machine with MetaEditor, compile the existing `.mq5` (for example
`metaeditor64.exe /compile:"<absolute source path>" /log:"<absolute log path>"`).
Review the actual log: command launch alone is not a successful compilation.
Load into MT5 with known broker history and validate cold attach, missing history,
partial buffers, timeframe/parameter change, daily rollover, history correction,
reconnect and tester/live prefix equivalence. Capture terminal event records and
compare them to the same fixtures before accepting production behavior.
