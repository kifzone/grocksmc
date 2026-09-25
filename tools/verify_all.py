#!/usr/bin/env python3
"""All requested gates. Overall nonzero until missing acceptance gates are built.
--implemented-only is an explicitly LIMITED development regression command.
"""
import argparse
from source_tools import ROOT
from verify_engine import static_check
from native_runner import run
from acceptance_status import blocked

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--implemented-only',action='store_true')
    args=p.parse_args()
    static_check()
    result=run();print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode:raise SystemExit(1)
    if args.implemented_only:
        print('PASS LIMITED regression suite. NOT full project acceptance.')
        raise SystemExit(0)
    print('NOT RUN: MQL5 compilation / MT5 runtime (environment unavailable)')
    for feature in ['whole-engine causal graph and replay',
                    'unified MTF MarketState', 'recursive scenarios', 'prediction/outcome ledger',
                    'historical analogs and calibration', 'walk-forward and robustness']:
        blocked(feature)
    raise SystemExit(2)
