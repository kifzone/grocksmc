#!/usr/bin/env python3
"""Future mutation on selected production bodies; no whole-engine guarantee."""
from native_runner import run
if __name__=='__main__':
    r=run('no_lookahead');print(r.stdout,end='');print(r.stderr,end='');raise SystemExit(r.returncode)
