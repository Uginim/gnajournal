#!/bin/bash
# 블로그 글쓰기 스타일 게이트 (그나저나 메모) — Claude Code 훅 어댑터
#
# 검사 규칙은 여기 없다. scripts/check-blog-style.sh 가 단일 출처다.
# 이 파일은 Claude Code 훅 이벤트(JSON)를 그 스크립트의 입력으로 바꾸고,
# 결과를 훅 규약(exit 2 + stderr)으로 옮기는 어댑터일 뿐이다.
#
# 규칙을 고칠 일이 있으면 scripts/check-blog-style.sh 를 고친다.
# 그래야 훅과 CI 가 같은 규칙을 본다.
#
# 이벤트:
#   PostToolUse(Write|Edit) → .md/.mdx 파일 내용 검사 (게시 콘텐츠, 전체 규칙)
#   Stop                    → 채팅 답변 검사 (문자 규칙만)

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CHECKER="$ROOT/scripts/check-blog-style.sh"

# 검사 스크립트가 없으면 통과시킨다. 훅 때문에 작업이 막히면 안 된다.
[ -x "$CHECKER" ] || exit 0

# 검사 결과를 훅 문맥에 맞게 다듬어 stderr 로 내보낸다.
emit() {
  printf '%s\n' "$1" \
    | sed 's/위 항목만 고치세요./위 항목만 고쳐 다시 진행하세요./' >&2
}

case "$EVENT" in
  Stop|SubagentStop)
    # 무한 루프 방지
    [ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0
    TEXT=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')
    [ -z "$TEXT" ] && exit 0
    if OUT=$(printf '%s' "$TEXT" | "$CHECKER" --lite - 2>/dev/null); then
      exit 0
    fi
    emit "${OUT/입력/채팅 답변}"
    exit 2 ;;
  PostToolUse)
    FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
    case "$FP" in
      */src/content/blog/*.md|*/src/content/blog/*.mdx) ;;
      *) exit 0 ;;
    esac
    [ -f "$FP" ] || exit 0
    if OUT=$("$CHECKER" "$FP" 2>/dev/null); then
      exit 0
    fi
    emit "$OUT"
    exit 2 ;;
  *) exit 0 ;;
esac
