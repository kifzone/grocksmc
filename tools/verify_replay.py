#!/usr/bin/env python3
"""Structure and VWAP full-prefix/incremental parity only."""
from native_runner import run
if __name__=='__main__':
    r=run('replay');print(r.stdout,end='');print(r.stderr,end='');raise SystemExit(r.returncode)
