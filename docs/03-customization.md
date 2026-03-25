# 커스터마이징 가이드

## 사이트 정보 변경

`src/consts.ts`에서 수정:

```typescript
export const SITE_TITLE = '그나저나';
export const SITE_DESCRIPTION = '그나저나, 이런저런 이야기를 기록하는 개인 블로그';
```

## 네비게이션 메뉴 변경

`src/components/Header.astro`에서 수정:

```astro
<div class="internal-links">
    <HeaderLink href="/">홈</HeaderLink>
    <HeaderLink href="/blog">글</HeaderLink>
    <HeaderLink href="/tags">태그</HeaderLink>
    <HeaderLink href="/search">검색</HeaderLink>
    <HeaderLink href="/about">소개</HeaderLink>
</div>
```

항목을 추가/삭제/순서 변경할 수 있습니다.

## 색상 변경

`src/styles/global.css`의 CSS 변수를 수정:

```css
:root {
    --accent: #3b82f6;        /* 메인 강조색 */
    --accent-dark: #1d4ed8;   /* 강조색 (어두운) */
    --bg: #ffffff;             /* 배경색 */
    --text: #1a1a2e;           /* 본문 텍스트 */
    --text-secondary: #64748b; /* 보조 텍스트 */
    --border: #e2e8f0;         /* 테두리 */
}

/* 다크모드 색상 */
[data-theme="dark"] {
    --accent: #60a5fa;
    --bg: #0f172a;
    --text: #e2e8f0;
    /* ... */
}
```

## 다크모드

### 동작 방식

1. 첫 방문: 시스템 설정(OS 다크모드)을 따름
2. 수동 전환: 헤더의 해/달 아이콘 클릭
3. 설정 저장: `localStorage`에 저장되어 재방문 시 유지

### 비활성화하려면

`src/components/Header.astro`에서 `<button id="theme-toggle">` 블록을 삭제하고,
`src/components/BaseHead.astro`에서 Dark Mode Script 블록을 삭제하면 됩니다.

## 폰트 변경

`src/components/BaseHead.astro`에서 폰트 CDN 링크를 변경:

```html
<!-- 현재: Pretendard -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css" />
```

`src/styles/global.css`의 `font-family`도 함께 변경:

```css
body {
    font-family: "Pretendard Variable", Pretendard, ...;
}
```

### 추천 대체 폰트

| 폰트 | CDN |
|------|-----|
| Noto Sans KR | `https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;700&display=swap` |
| IBM Plex Sans KR | `https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;700&display=swap` |

## 푸터 변경

`src/components/Footer.astro`에서 수정:

```astro
<footer>
    <p>&copy; {today.getFullYear()} 그나저나. All rights reserved.</p>
    <p class="powered-by">
        Powered by <a href="https://astro.build/">Astro</a>
    </p>
</footer>
```

## 소개 페이지 수정

`src/pages/about.astro`를 직접 편집합니다. 일반 HTML + Astro 컴포넌트를 사용할 수 있습니다.
