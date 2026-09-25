"""Explicitly unimplemented acceptance gates. Exit 2 means BLOCKED, not PASS."""
import sys

def blocked(feature):
    print(f'NOT IMPLEMENTED: {feature}')
    print('Required implementation or runtime evidence is missing; this gate cannot pass.')
    return 2
