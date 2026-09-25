"""Test selected production MQL function bodies, not a parallel Python engine.

Only array syntax is adapted; support APIs are explicit fixture stubs in shim.
MT5 event scheduling/CopyBuffer semantics, full indicator and MQL typing require
MetaEditor/terminal validation separately. Builds in a temporary directory.
"""
import re
import subprocess
import tempfile
from source_tools import SOURCE, ROOT, definitions

FUNCTIONS = ['IsFractalHigh', 'IsFractalLow', 'FindLastBearishOB', 'FindLastBullishOB',
             'DetectStructure', 'ManageSetupLifecycle', 'FillEMAAndVWAP', 'AddOrMergeFVG',
             'DetectZones', 'DetectFVG', 'IsDuplicateOB', 'IsDuplicateBreaker',
             'AddBreakerBlock', 'BuildOBStrengthIndex', 'GenerateOBId', 'DetectOrderBlocks']


def adapt(text):
    # MQL array reference parameters -> range-checked fixture arrays
    text = re.sub(r'(const\s+)?(double|datetime|long|SZone|SOrderBlock)\s*&\s*(\w+)\[\]',
                  lambda m: f'{m[1] or ""}Array<{m[2]}> &{m[3]}', text)
    text = re.sub(r'\b(double|datetime|long|SZone|SOrderBlock)\s+(\w+)\[\](\s*,\s*\w+\[\])*\s*;',
                  lambda m: 'Array<'+m[1]+'> '+m[0][len(m[1]):].strip().replace('[]', ''), text)
    return text


def run(group='all', text=None):
    text = SOURCE.read_text() if text is None else text
    defs = definitions(text)
    structs = '\n'.join(re.findall(r'(?m)^struct\s+\w+\s*\{[^}]*\};', text))
    cpp = (ROOT/'tests/native_shim.hpp').read_text() + '\n' + structs + '''
Array<SStructureBreak> g_structures;
Array<SOrderBlock> g_order_blocks;
Array<SFVG> g_fvgs;
Array<SZone> g_zones;
Array<SBreaker> g_breakers;
Array<int> g_ob_strength_idx;
STradeSetup g_trade_setup;
SActiveSetup g_active_setup;
'''
    cpp += '\n'.join(adapt(defs[name]) for name in FUNCTIONS)
    cpp += '\n' + (ROOT/'tests/native_cases.cpp').read_text()
    with tempfile.TemporaryDirectory(prefix='qsmc-tests-') as tmp:
        from pathlib import Path
        source, exe = Path(tmp)/'cases.cpp', Path(tmp)/'cases'
        source.write_text(cpp)
        subprocess.run(['g++','-std=c++17','-O1','-g','-fsanitize=undefined',
                        '-fno-sanitize-recover=all',str(source),'-o',str(exe)], check=True)
        return subprocess.run([str(exe),group], text=True, capture_output=True)


if __name__ == '__main__':
    result=run()
    print(result.stdout,end='')
    print(result.stderr,end='')
    raise SystemExit(result.returncode)
