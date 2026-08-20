#!/bin/bash
# 글쓰기 스타일 검사 (그나저나 메모)
#
# 규칙의 단일 출처다. Claude Code 훅(.claude/hooks/blog-style-check.sh)과
# CI(.github/workflows/ci.yml)가 모두 이 스크립트를 호출한다.
# 규칙을 두 곳에 적으면 반드시 어긋나므로 여기에만 적는다.
#
# 정식 규격은 docs/writing-style.md 다. 이 스크립트는 그중 기계로 잡히는
# 항목만 구현한다.
#
# 사용법
#   check-blog-style.sh <파일>...        게시 콘텐츠 검사 (전체 규칙)
#   check-blog-style.sh --lite <파일>    문자 규칙만 검사 (채팅 답변용)
#   cat text | check-blog-style.sh --lite -
#
# 종료 코드
#   0  위반 없음
#   1  위반 있음 (내용은 stdout)
#
# 블로그 목소리는 존댓말(~합니다/됩니다/입니다)이므로 그건 절대 잡지 않는다.
# 코드블록과 인라인 코드는 검사에서 제외한다.

set -uo pipefail

MODE="full"
if [ "${1:-}" = "--lite" ]; then
  MODE="lite"
  shift
fi

if [ $# -eq 0 ]; then
  echo "usage: check-blog-style.sh [--lite] <파일>... | - " >&2
  exit 2
fi

# 코드펜스와 인라인 코드를 걷어낸다. 코드 안의 문자는 규칙 대상이 아니다.
strip_code() {
  awk '
    /^[[:space:]]*```/ { infence = !infence; next }
    !infence { print }
  ' | sed 's/`[^`]*`//g'
}

# 한 덩어리의 텍스트를 검사해 위반 목록을 stdout 으로 낸다.
check_text() {
  local stripped="$1" v=""

  printf '%s' "$stripped" | grep -q '—' && \
    v="${v}- em dash(—) 사용됨 → 제목은 콜론(:), 문장 중간은 쉼표, 또는 문장 분리.\n"
  printf '%s' "$stripped" | grep -q '·' && \
    v="${v}- 가운뎃점(·) 나열 사용됨 → 쉼표로 나열하거나 문장으로 풀어쓸 것.\n"
  printf '%s' "$stripped" | grep -qE '\)\*\*[가-힣]' && \
    v="${v}- 마크다운 굵게 함정: )** 뒤 한글은 렌더 안 됨 → 닫는 ** 뒤에 공백이나 쉼표.\n"

  # 필러 도입부와 어색한 표현은 게시 콘텐츠에서만 잡는다.
  if [ "$MODE" = "full" ]; then
    printf '%s' "$stripped" | grep -qE '흥미로운 점은|놀랍게도|재미있는 건|재밌는 건' && \
      v="${v}- 필러 도입부(흥미로운 점은/놀랍게도 등) → 빼고 사실을 바로 서술.\n"
    printf '%s' "$stripped" | grep -qE '키잉|판별선|이름 집합' && \
      v="${v}- 압축 조어/음차(키잉, 판별선, 이름 집합) → 캐시 키에 포함된다, 기준은, 목록 처럼 풀어쓸 것.\n"
    printf '%s' "$stripped" | grep -qE '싣는|싣고|실린다|실리는|실리지' && \
      v="${v}- 운반 메타포(싣다/실리다) → 전송하다, 포함하다, 로드하다.\n"
    printf '%s' "$stripped" | grep -qE '\*\*[^*]+\.\*\*' && \
      v="${v}- 굵은 라벨 뒤 마침표(**라벨.**) → 콜론 형식(**라벨**: 내용).\n"
    printf '%s' "$stripped" | grep -qE '다른 축|두 축|남은 축|축입니다|축이다' && \
      v="${v}- 추상 메타포 명사(축) → 가리키는 대상을 그대로(예: 비용을 가르는 건 A와 B 둘).\n"
  fi

  printf '%b' "$v"
}

FOUND=0
for f in "$@"; do
  if [ "$f" = "-" ]; then
    text=$(cat)
    label="입력"
  else
    [ -f "$f" ] || continue
    text=$(cat "$f")
    label="$f"
  fi
  [ -z "$text" ] && continue

  stripped=$(printf '%s\n' "$text" | strip_code)
  violations=$(check_text "$stripped")

  if [ -n "$violations" ]; then
    printf '글쓰기 스타일 위반 (%s):\n%s' "$label" "$violations"
    FOUND=1
  fi
done

if [ "$FOUND" -eq 1 ]; then
  printf '\n존댓말 종결(~합니다/됩니다/입니다)은 정상입니다. 위 항목만 고치세요.\n'
  printf '정식 규격: docs/writing-style.md\n'
  exit 1
fi

exit 0
