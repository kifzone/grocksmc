#!/usr/bin/env python3
"""Selected structure chronology/evidence checks, not whole graph certification."""
from native_runner import run
if __name__=='__main__':
    r=run('causality');print(r.stdout,end='');print(r.stderr,end='');raise SystemExit(r.returncode)
