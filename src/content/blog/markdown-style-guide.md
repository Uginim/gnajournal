---
title: 'Markdown 작성 가이드'
description: '블로그 글을 작성할 때 사용할 수 있는 Markdown 문법을 정리합니다.'
pubDate: 'Mar 23 2026'
heroImage: '../../assets/blog-placeholder-4.jpg'
tags: ['개발', '가이드']
draft: true
---

이 글에서는 블로그 포스트 작성에 사용할 수 있는 기본적인 Markdown 문법을 정리합니다.

## 제목

# H1 제목
## H2 제목
### H3 제목
#### H4 제목

## 텍스트 서식

**굵은 글씨**, *기울임*, ~~취소선~~을 사용할 수 있습니다.

## 목록

### 순서 없는 목록
- 항목 1
- 항목 2
  - 하위 항목

### 순서 있는 목록
1. 첫 번째
2. 두 번째
3. 세 번째

## 코드

인라인 코드: `console.log('hello')`

코드 블록:

```typescript
function greet(name: string): string {
  return `안녕하세요, ${name}님!`;
}
```

## 인용

> 좋은 코드는 좋은 문서이다.

## 링크와 이미지

[Astro 공식 사이트](https://astro.build/)

## 표

| 항목 | 설명 |
|------|------|
| Astro | 정적 사이트 생성기 |
| Markdown | 마크업 언어 |
