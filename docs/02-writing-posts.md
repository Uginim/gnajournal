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
