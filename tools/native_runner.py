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
             'AddBreakerBlock', 'BuildOBStrengthIndex', 'GenerateOBId', 'DetectOrderBlocks',
             # P1: execute the production search/flag/confirmation functions, not copies.
             'OBMid', 'BuildOBPriceIndex', 'BinarySearchNearestOB', 'SelectEntryOB',
             'IsLatestStructureConfirmed', 'MarkSignalFactor', 'UpdateSignalMask',
             'CheckSignalPattern']


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
    bits = '\n'.join(re.findall(r'(?m)^#define BIT_\w+\s+[^\n]+', text))
    flags = re.search(r'(?s)\benum ENUM_SIGNAL_FLAG\s*\{[^}]*\};', text)
    assert flags, 'missing P1 signal flag indexes'
    cpp = (ROOT/'tests/native_shim.hpp').read_text() + '\n' + bits + '\n' + flags[0] + '\n' + structs + '''
Array<SStructureBreak> g_structures;
Array<SOrderBlock> g_order_blocks;
Array<SFVG> g_fvgs;
Array<SLiquidity> g_liquidity;
Array<SZone> g_zones;
Array<SBreaker> g_breakers;
Array<int> g_ob_strength_idx, g_ob_price_idx;
Array<datetime> g_buf_t;
SDealingRange g_range;
int g_signal_mask=0;
bool g_signal_flags[FLAG_COUNT];
string g_ob_search_path;
STradeSetup g_trade_setup;
SActiveSetup g_active_setup;
bool fixture_ote=false;
bool GetOTEZone(double &top,double &bottom,bool &bullish){
 top=120; bottom=110; bullish=true; return fixture_ote;
}
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
