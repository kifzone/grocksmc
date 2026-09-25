#!/usr/bin/env python3
"""Negative controls: the tests must reject deliberately reintroduced bugs."""
from native_runner import run
from source_tools import SOURCE

MUTANTS = [
 ('live distance invalidation', 'engine', 'double dist=MathAbs(c[closed]-zoneMid);',
  'double dist=MathAbs(c[live]-zoneMid);'),
 ('stale displacement', 'causality',
  '// A previous break\'s displacement is not evidence for this event.\n      displacement=false;',
  '// MUTANT: leak previous displacement'),
 ('future ATR', 'no_lookahead', 'double cur_atr=atr[i]; // historical acceptance',
  'double cur_atr=atr[total-1]; // historical acceptance'),
 ('pre-availability confirmation', 'engine',
  'if(closed<=g_active_setup.created_bar || t[closed]<g_active_setup.created_time) return;',
  '// MUTANT: allow retroactive confirmation'),
 ('FVG identity', 'engine',
  'if(g_fvgs[i].bar==fvg.bar && g_fvgs[i].bullish==fvg.bullish) return;',
  'if(false) return;'),
]

if __name__=='__main__':
    text=SOURCE.read_text()
    baseline=run('all',text)
    assert baseline.returncode == 0, f'baseline must pass before testing mutants: {baseline.stderr}'
    for name,group,before,after in MUTANTS:
        assert before in text, f'mutant target missing: {name}'
        result=run(group,text.replace(before,after,1))
        assert result.returncode != 0 and 'Assertion' in result.stderr, f'mutant survived or failed unexpectedly: {name}: {result.stderr}'
        print(f'PASS negative control detected: {name}')
