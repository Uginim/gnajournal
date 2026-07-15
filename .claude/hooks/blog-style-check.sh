#!/bin/bash
# 블로그 글쓰기 스타일 게이트 (그나저나 메모)
# 블로그 목소리는 존댓말(~합니다/됩니다/입니다)이므로 그건 절대 잡지 않는다.
# 잡는 것: em dash(—), 가운뎃점(·), 마크다운 굵게 함정, 필러 도입부.
# 코드블록(``` ```)과 인라인 코드(`...`)는 검사에서 제외한다.
#
# 이벤트:
#   PostToolUse(Write|Edit) → .md/.mdx 파일 내용 검사 (게시 콘텐츠)
#   Stop                    → 채팅 답변(last_assistant_message) 검사 (em dash·가운뎃점만)
# 위반 시 exit 2 + stderr → Claude가 스스로 고쳐 다시 진행.

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')

TEXT=""
CTX=""
MODE=""   # full = 게시 콘텐츠(필러까지), lite = 채팅(문자만)

case "$EVENT" in
  Stop|SubagentStop)
    # 무한 루프 방지
    [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0
    TEXT=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')
    CTX="채팅 답변"
    MODE="lite" ;;
  PostToolUse)
    FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
    case "$FP" in
      */src/content/blog/*.md|*/src/content/blog/*.mdx) TEXT=$(cat "$FP" 2>/dev/null); CTX="$FP"; MODE="full" ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac

[ -z "$TEXT" ] && exit 0

# 코드펜스 제거 + 인라인 코드 제거
STRIPPED=$(printf '%s\n' "$TEXT" | awk '
  /^[[:space:]]*```/ { infence = !infence; next }
  !infence { print }
' | sed 's/`[^`]*`//g')

V=""
printf '%s' "$STRIPPED" | grep -q '—' && \
  V="${V}- em dash(—) 사용됨 → 제목은 콜론(:), 문장 중간은 쉼표, 또는 문장 분리.\n"
printf '%s' "$STRIPPED" | grep -q '·' && \
  V="${V}- 가운뎃점(·) 나열 사용됨 → 쉼표로 나열하거나 문장으로 풀어쓸 것.\n"
printf '%s' "$STRIPPED" | grep -qE '\)\*\*[가-힣]' && \
  V="${V}- 마크다운 굵게 함정: )** 뒤 한글은 렌더 안 됨 → 닫는 ** 뒤에 공백이나 쉼표.\n"

# 필러 도입부와 어색한 표현은 게시 콘텐츠(.md)에서만
if [ "$MODE" = "full" ]; then
  printf '%s' "$STRIPPED" | grep -qE '흥미로운 점은|놀랍게도|재미있는 건|재밌는 건' && \
    V="${V}- 필러 도입부(흥미로운 점은/놀랍게도 등) → 빼고 사실을 바로 서술.\n"
  printf '%s' "$STRIPPED" | grep -qE '키잉|판별선|이름 집합' && \
    V="${V}- 압축 조어/음차(키잉, 판별선, 이름 집합) → 캐시 키에 포함된다, 기준은, 목록 처럼 풀어쓸 것.\n"
  printf '%s' "$STRIPPED" | grep -qE '싣는|싣고|실린다|실리는|실리지' && \
    V="${V}- 운반 메타포(싣다/실리다) → 전송하다, 포함하다, 로드하다.\n"
  printf '%s' "$STRIPPED" | grep -qE '\*\*[^*]+\.\*\*' && \
    V="${V}- 굵은 라벨 뒤 마침표(**라벨.**) → 콜론 형식(**라벨**: 내용).\n"
  printf '%s' "$STRIPPED" | grep -qE '다른 축|두 축|남은 축|축입니다|축이다' && \
    V="${V}- 추상 메타포 명사(축) → 가리키는 대상을 그대로(예: 비용을 가르는 건 A와 B 둘).\n"
fi

[ -z "$V" ] && exit 0

printf '글쓰기 스타일 위반 (%s):\n%b\n존댓말 종결(~합니다/됩니다/입니다)은 정상입니다. 위 항목만 고쳐 다시 진행하세요.\n' \
  "$CTX" "$V" >&2
exit 2
