#!/bin/bash
# Robbyrussell(Oh My Zsh) 스타일 프롬프트(➜ 디렉터리 git:(브랜치) ✗)
# + 모델명과 이번 턴의 캐시 read/write 토큰(콤마 포맷)을 이어서 표시한다.
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$PWD
dir_name=$(basename "$cwd")

git_segment=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  dirty=""
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty=$(printf ' \033[33m\xe2\x9c\x97\033[0m')
  fi
  git_segment=$(printf ' \033[1;34mgit:(\033[31m%s\033[1;34m)\033[0m%s' "$branch" "$dirty")
fi

model=$(echo "$input" | jq -r '.model.display_name')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

# 천 단위 콤마 포맷
comma() {
  printf '%d' "$1" | rev | sed -E 's/([0-9]{3})/\1,/g' | rev | sed -E 's/^,//'
}
read_fmt=$(comma "$cache_read")
write_fmt=$(comma "$cache_write")

printf '\033[1;32m\xe2\x9e\x9c\033[0m  \033[36m%s\033[0m%s \033[2m| %s | cache read %s | write %s\033[0m\n' \
  "$dir_name" "$git_segment" "$model" "$read_fmt" "$write_fmt"
