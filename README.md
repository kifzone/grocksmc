# Quantum SMC — audited correctness increment

Entry point: `QuantumSMC_AI_Pro_v5.6.9_COMPACT_DASHBOARD.mq5` (property version 5.71).
The checkout did not contain `KLJ.mq5`; the existing file was preserved.

**This is not a completed predictive engine or a certified no-lookahead indicator.**
See [VALIDATION_REPORT.md](VALIDATION_REPORT.md) for exact test scope and remaining
acceptance gates. No statistical performance or calibrated probabilities are claimed.

- [Architecture audit](ARCHITECTURE_REPORT.md)
- [Complete baseline dependency map](docs/BASELINE_DEPENDENCIES.md)
- [Causal model](CAUSAL_MODEL.md)
- [Prediction status/design](PREDICTION_MODEL.md)
- [Replay status/design](REPLAY_MODEL.md)
- [Changes and compatibility](CHANGELOG.md)

Requires Python 3 and g++ with C++17/UBSan for the limited local regression harness:

```sh
python3 tools/verify_all.py --implemented-only
python3 tools/verify_mutation_guards.py
```

The harness extracts selected production MQL function bodies; it is not a separate
Python indicator. MQL5 compilation and MT5 runtime verification remain required.
`python3 tools/verify_all.py` returns **2** because whole-project acceptance is
incomplete. Predictive/scenario/outcome entry points likewise return BLOCKED,
not fabricated passes. See the report before deploying this patch.
