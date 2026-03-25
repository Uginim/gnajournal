# 시작하기

## 요구 사항

- Node.js >= 22.12.0
- npm

## 설치

```bash
npm install
```

## 개발 서버

```bash
npm run dev
```

http://localhost:4321/ 에서 확인할 수 있습니다.

## 빌드

```bash
npm run build
```

`dist/` 폴더에 정적 파일이 생성됩니다.

## 미리보기

빌드 결과물을 로컬에서 확인:

```bash
npm run preview
```

## 프로젝트 구조

```
src/
├── assets/              # 이미지 등 정적 에셋
├── components/          # 재사용 컴포넌트
│   ├── BaseHead.astro   # HTML <head> (메타, 폰트, 분석 스크립트)
│   ├── Header.astro     # 상단 네비게이션 + 다크모드 토글
│   ├── Footer.astro     # 하단 푸터
│   ├── FormattedDate.astro  # 한국어 날짜 포맷
│   ├── HeaderLink.astro # 네비게이션 링크 (active 상태 자동 감지)
│   ├── AdBanner.astro   # Google AdSense 광고
│   └── Giscus.astro     # Giscus 댓글
├── content/
│   └── blog/            # 블로그 글 (Markdown/MDX)
├── layouts/
│   └── BlogPost.astro   # 블로그 글 레이아웃
├── pages/
│   ├── index.astro      # 홈 (최근 글 5개)
│   ├── about.astro      # 소개 페이지
│   ├── search.astro     # 검색 페이지
│   ├── rss.xml.js       # RSS 피드
│   ├── blog/
│   │   ├── index.astro      # 전체 글 목록
│   │   └── [...slug].astro  # 개별 글 페이지
│   └── tags/
│       ├── index.astro      # 전체 태그 목록
│       └── [tag].astro      # 태그별 글 목록
├── styles/
│   └── global.css       # 전역 스타일 (다크모드 포함)
├── content.config.ts    # 콘텐츠 스키마 정의
└── consts.ts            # 사이트 이름, 설명 등 상수
```
