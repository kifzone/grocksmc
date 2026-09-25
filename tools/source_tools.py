"""Limited MQL source inventory, NOT an MQL compiler or type checker."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'QuantumSMC_AI_Pro_v5.6.9_COMPACT_DASHBOARD.mq5'


def mask(text):
    """Preserve offsets/newlines while hiding comments and quoted literals."""
    return re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                  lambda m: re.sub(r'[^\n]', ' ', m[0]), text)


def definitions(text):
    clean = mask(text)
    pattern = r'(?m)^(?:void|bool|int|double|string|color|datetime)\s+(\w+)\s*\([^;{}]*\)\s*\{'
    result = {}
    for m in re.finditer(pattern, clean):
        depth, end = 1, m.end()
        while depth and end < len(clean):
            depth += (clean[end] == '{') - (clean[end] == '}')
            end += 1
        if depth:
            raise ValueError(f'unclosed body: {m[1]}')
        if m[1] in result:
            raise ValueError(f'duplicate definition: {m[1]}')
        result[m[1]] = text[m.start():end]
    return result


def body(name):
    return definitions(SOURCE.read_text())[name]
