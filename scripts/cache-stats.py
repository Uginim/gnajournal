#!/usr/bin/env python3
"""Claude Code 세션 JSONL에서 요청별 캐시 카운트를 뽑는다.

사용법:
  python3 scripts/cache-stats.py            # 이 프로젝트의 최신 세션, 최근 10건
  python3 scripts/cache-stats.py -n 30      # 최근 30건
  python3 scripts/cache-stats.py --spikes   # cache_creation 20k 이상 급증 지점만
"""
import json, io, glob, os, sys

PROJ = os.path.expanduser(
    '~/.claude/projects/' + os.getcwd().replace('/', '-'))
n = int(sys.argv[sys.argv.index('-n') + 1]) if '-n' in sys.argv else 10
spikes = '--spikes' in sys.argv

rows = []
for f in sorted(glob.glob(PROJ + '/*.jsonl')):
    for line in io.open(f, encoding='utf-8'):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get('type') != 'assistant':
            continue
        m = d.get('message') or {}
        u = m.get('usage')
        if not u:
            continue
        rows.append((d.get('timestamp', '')[:19], m.get('model', '?'),
                     u.get('cache_read_input_tokens', 0),
                     u.get('cache_creation_input_tokens', 0)))
rows.sort()
out = [r for r in rows if r[3] > 20000] if spikes else rows[-n:]
print(f"{'시각(UTC)':20} {'모델':26} {'cache_read':>11} {'cache_create':>13}")
for t, model, r, c in out:
    print(f"{t:20} {model:26} {r:>11,} {c:>13,}")
