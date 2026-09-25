#!/usr/bin/env python3
"""Static source lint + selected-function execution; never labels this MQL compile."""
import re
from source_tools import SOURCE, mask, definitions
from native_runner import run

BUILTINS = set('''Alert ArrayGetAsSeries ArrayInitialize ArrayResize ArraySetAsSeries
ArraySize ChartGetInteger ChartRedraw CopyBuffer CopyClose CopyHigh CopyLow
DoubleToString EnumToString GetLastError IndicatorRelease IndicatorSetString
IntegerToString MQLInfoInteger MathAbs MathMax MathMin MathRound ObjectCreate
ObjectDelete ObjectFind ObjectMove ObjectSetDouble ObjectSetInteger ObjectSetString
ObjectsDeleteAll PeriodSeconds PlotIndexSetDouble PlotIndexSetInteger Print
ResetLastError SetIndexBuffer StringFind StringFormat StringLen StringReplace
StringSplit StringSubstr StringToDouble StringTrimLeft StringTrimRight StructToTime
SymbolInfoInteger TimeCurrent TimeToString TimeToStruct iADX iATR iClose iHigh iLow
iMA iRSI iTime if for while return'''.split())


def signature(header):
    params = header[header.index('(')+1:header.rindex(')')]
    result=[]
    for param in params.split(','):
        param=param.split('=')[0].strip()
        if not param:
            continue
        words=re.findall(r'[A-Za-z_]\w*',param)
        const=words and words[0]=='const'
        result.append(('const ' if const else '')+words[int(const)]+
                      ('&' if '&' in param else '')+('[]' if '[' in param else ''))
    return result


def static_check():
    text=SOURCE.read_text();clean=mask(text);defs=definitions(text)
    stack=[];pairs={')':'(',']':'[','}':'{'}
    for char in clean:
        if char in '([{':stack.append(char)
        elif char in ')]}':
            assert stack and stack.pop()==pairs[char], 'unbalanced delimiters'
    assert not stack, 'unclosed delimiters'
    macros=set(re.findall(r'(?m)^#define\s+(\w+)',clean))
    calls=set(re.findall(r'\b(\w+)\s*\(',clean))
    unknown=calls-set(defs)-BUILTINS-macros
    assert not unknown, f'unresolved function names: {sorted(unknown)}'
    decls=re.findall(r'(?m)^(?:void|bool|int|double|string|color|datetime)\s+(\w+)\s*(\([^;{}]*\))\s*;', clean)
    for name,params in decls:
        assert name in defs, f'undefined forward declaration {name}'
        header=mask(defs[name]).split('{')[0]
        assert signature(params)==signature(header), f'forward signature mismatch {name}'
    for name in ['DetectStructure','DetectZones','DetectFVG','DetectOrderBlocks']:
        assert 'CopyBuffer(h_atr,0,0,total,atr)!=total' in defs[name], name
    assert 'atr[total-1]' not in defs['DetectZones']
    assert 'c[live]' not in defs['ManageSetupLifecycle']
    assert 'TimeCurrent' not in defs['ScoreSession']
    assert 'TimeCurrent' not in defs['UpdateSignalMask']
    assert 'PERIOD_D1,0' not in defs['GreedyFindBestTarget']
    assert 'if(run_engine && !g_data_ready)' in defs['OnCalculate']
    assert 'g_htf_cache_time=ht; g_d1_cache_time=dt; // commit successful cache only' in defs['ComputeHTFBias']
    assert 'CalculateProbability' not in defs
    assert 'INSUFFICIENT DATA' in defs['DrawQuantumDashboard']
    print(f'PASS limited static lint: {len(defs)} unique definitions, {len(decls)} matched forwards, delimiters/call names/regression guards')
    print('NOT RUN: whole-indicator MQL5 syntax/type compilation (MetaEditor unavailable)')


if __name__=='__main__':
    static_check()
    result=run('engine');print(result.stdout,end='');print(result.stderr,end='')
    raise SystemExit(result.returncode)
