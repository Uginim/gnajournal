# 글 작성 가이드

## 새 글 작성

`src/content/blog/` 디렉토리에 `.md` 또는 `.mdx` 파일을 생성합니다.

### 파일명 규칙

파일명이 URL 슬러그가 됩니다:
- `my-first-post.md` → `/blog/my-first-post/`
- 영문 소문자, 하이픈 사용 권장

### Frontmatter

모든 글은 파일 상단에 frontmatter가 필요합니다:

```markdown
---
title: '글 제목'
description: '글에 대한 간단한 설명 (검색/SEO에 사용)'
pubDate: 'Mar 25 2026'
updatedDate: 'Mar 26 2026'     # 선택: 수정일
heroImage: '../../assets/이미지.jpg'  # 선택: 대표 이미지
tags: ['개발', 'Astro']        # 선택: 태그 목록
draft: false                    # 선택: true면 비공개
---

여기에 글 내용을 작성합니다.
```

### 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `title` | string | 글 제목 |
| `description` | string | 글 설명 (SEO, 목록에서 표시) |
| `pubDate` | string/Date | 발행일 |

### 선택 필드

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `updatedDate` | string/Date | - | 수정일 |
| `heroImage` | string | - | 대표 이미지 경로 |
| `tags` | string[] | `[]` | 태그 목록 |
| `draft` | boolean | `false` | `true`면 빌드에서 제외 |

## 글 비공개 처리

frontmatter에 `draft: true`를 추가하면 됩니다:

```markdown
---
title: '작성 중인 글'
draft: true
---
```

- 빌드 시 사이트에 포함되지 않음
- 글 목록, 태그, 검색, RSS에서 모두 제외
- 다시 공개하려면 `draft: false`로 변경하거나 필드를 삭제

## 이미지 사용

### 에셋 이미지 (권장)

`src/assets/`에 이미지를 넣고 상대 경로로 참조:

```markdown
heroImage: '../../assets/my-image.jpg'
```

Astro가 자동으로 최적화(WebP 변환, 리사이징)합니다.

### 본문 내 이미지

Markdown 문법 사용:

```markdown
![대체 텍스트](../../assets/screenshot.png)
```

### 게시 전 이미지 점검 (필수)

애드센스 심사는 저작권 침해와 복제 콘텐츠를 반려 사유로 둔다. 아래 다섯 가지를
게시 전에 확인한다. 초안 상태에서는 지키지 않아도 되지만 `draft: false`로 바꾸기 전에
반드시 통과해야 한다.

**1. 템플릿 기본 이미지를 그대로 두지 않는다**

`blog-placeholder-*.jpg`는 Astro 블로그 템플릿이 딸려 보낸 견본이다. 이걸 달고 게시하면
차별화 없는 사이트 신호가 된다. 자체 히어로 이미지로 교체한다.

```bash
grep -l 'blog-placeholder' src/content/blog/*.md src/content/blog/*.mdx
```

여기 걸린 파일 중 `draft: true`가 아닌 것이 있으면 게시하면 안 된다.

**2. 외부 이미지는 캡션에 출처와 링크를 단다**

남의 문서 스크린샷이나 도식을 쓸 때는 인용임이 드러나야 한다. alt 텍스트만으로는
부족하고, 이미지 바로 아래 인용문으로 출처와 원문 링크를 적는다.

```markdown
![도식 설명을 담은 대체 텍스트](../../assets/외부-도식.png)

> 도식이 무엇을 보여주는지 한 줄. 출처: [문서 이름](https://원문-링크)
```

**3. 모든 이미지에 대체 텍스트를 채운다**

`![](...)`처럼 비워 두지 않는다. 그림이 무엇을 보여주는지 문장으로 적는다. 검색 노출과
접근성에 함께 작용한다.

```bash
grep -rn '!\[\](' src/content/blog/
```

출력이 있으면 채운다.

**4. 히어로 이미지는 자체 생성분만 쓴다**

[hero-image-prompt.md](./hero-image-prompt.md)의 프롬프트로 만든다. 참고 이미지를 함께
첨부해야 그림체가 일관된다. 웹에서 주워 온 이미지를 쓰지 않는다.

**5. 도식은 SVG 원본을 함께 커밋한다**

PNG만 남기면 나중에 문구 하나 고치려고 처음부터 다시 그리게 된다. SVG를 원본으로 두고
필요할 때 PNG를 뽑는다.

### 쓰지 않는 자산 정리

어느 글에서도 참조하지 않는 이미지는 저장소만 무겁게 한다. Astro는 참조된 것만 번들에
넣으므로 사이트 출력에는 영향이 없지만, 주기적으로 정리한다.

```bash
for f in src/assets/*; do
  grep -rq "$(basename "$f")" src/ || echo "미사용: $f"
done
```

## MDX 사용

`.mdx` 확장자를 사용하면 Markdown 안에서 Astro 컴포넌트를 사용할 수 있습니다:

```mdx
---
title: 'MDX 글'
description: '컴포넌트를 포함한 글'
pubDate: 'Mar 25 2026'
tags: ['개발']
---

import MyComponent from '../../components/MyComponent.astro';

일반 Markdown 문법도 사용 가능합니다.

<MyComponent />
```

## 태그 사용 팁

- 태그는 자유롭게 작성 (자동으로 태그 페이지 생성)
- 일관된 태그명 사용 권장 (예: "개발", "일상", "Astro")
- 태그 페이지: `/tags/` 에서 전체 태그 목록 확인
- 개별 태그: `/tags/개발/` 형태로 접근
