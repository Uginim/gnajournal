---
title: 'Astro로 블로그 만들기'
description: 'Astro 프레임워크를 사용해서 개인 블로그를 구축한 과정을 정리합니다.'
pubDate: 'Mar 25 2026'
heroImage: '../../assets/blog-placeholder-2.jpg'
tags: ['개발', 'Astro', '웹']
---

이 블로그는 [Astro](https://astro.build/)로 만들었습니다. Astro를 선택한 이유와 구축 과정을 간단히 정리해봅니다.

## 왜 Astro인가

- **빠르다**: 기본적으로 JavaScript를 최소한으로 보내기 때문에 로딩이 빠릅니다
- **Markdown 지원**: 글을 Markdown으로 작성할 수 있어서 편합니다
- **Content Collections**: 타입 안전한 콘텐츠 관리가 가능합니다

## 주요 기능

### 다크 모드
시스템 설정을 따르거나, 헤더의 토글 버튼으로 전환할 수 있습니다.

### 태그 시스템
각 글에 태그를 달아서 분류할 수 있습니다.

### 검색
클라이언트 사이드 검색으로 빠르게 글을 찾을 수 있습니다.

```javascript
// Astro의 Content Collections 사용 예시
const posts = await getCollection('blog');
const sortedPosts = posts.sort(
  (a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf()
);
```

Astro는 정적 사이트 생성에 최적화되어 있어서 블로그에 딱 맞는 프레임워크입니다.
