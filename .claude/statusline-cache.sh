#!/bin/bash
# 상태줄에 모델과 이번 턴의 캐시 read/write 토큰을 표시한다.
python3 -c "
import sys, json
d = json.load(sys.stdin)
def find(o, key):
    if isinstance(o, dict):
        if key in o: return o[key]
        for v in o.values():
            r = find(v, key)
            if r is not None: return r
    elif isinstance(o, list):
        for v in o:
            r = find(v, key)
            if r is not None: return r
    return None
r = find(d, 'cache_read_input_tokens') or 0
c = find(d, 'cache_creation_input_tokens') or 0
model = (d.get('model') or {}).get('display_name', '')
print(f'{model} | cache read {r:,} | write {c:,}')
"
