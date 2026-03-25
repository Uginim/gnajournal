# Google AdSense 설정 가이드

## 개요

블로그 글 하단(본문과 댓글 사이)에 광고가 표시됩니다.

## 1단계: AdSense 가입

1. https://www.google.com/adsense/ 접속
2. Google 계정으로 로그인
3. 사이트 URL 입력 (배포 후 도메인)
4. 약관 동의 후 신청

> AdSense 승인에는 보통 1~2주 소요됩니다. 콘텐츠가 충분해야(약 10개 이상의 글) 승인이 잘 됩니다.

## 2단계: 스크립트 설정

승인 완료 후 AdSense 대시보드에서 **클라이언트 ID**를 확인합니다.
`ca-pub-XXXXXXXXXXXXXXXX` 형태입니다.

### BaseHead.astro 수정

`src/components/BaseHead.astro`에서 AdSense 스크립트 주석을 해제하고 ID를 교체:

```html
<!-- 주석 해제 후 ID 교체 -->
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-본인ID" crossorigin="anonymous"></script>
```

## 3단계: 광고 단위 생성

1. AdSense 대시보드 > 광고 > 광고 단위별
2. "디스플레이 광고" 선택
3. 광고 단위 이름 입력 (예: "블로그 글 하단")
4. 생성된 `data-ad-slot` 값 복사

### AdBanner.astro 수정

`src/components/AdBanner.astro`에서 두 값을 교체:

```typescript
const CLIENT_ID = 'ca-pub-본인클라이언트ID';
const AD_SLOT = '생성된광고단위ID';
```

## 광고 위치

현재 설정된 위치:
- **블로그 글 하단**: 본문이 끝나고 댓글 섹션 전

### 다른 위치에 추가하려면

원하는 페이지/레이아웃에서:

```astro
---
import AdBanner from '../components/AdBanner.astro';
---

<AdBanner />
```

### format 옵션

```astro
<AdBanner format="auto" />       <!-- 반응형 (기본값) -->
<AdBanner format="horizontal" /> <!-- 가로형 -->
<AdBanner format="rectangle" />  <!-- 사각형 -->
```

## 주의사항

- AdSense 정책 위반 시 계정이 정지될 수 있습니다
- 페이지당 광고 수를 3개 이하로 유지하는 것을 권장합니다
- 본인이 광고를 클릭하지 마세요 (정책 위반)
- 콘텐츠 대비 광고가 너무 많으면 사용자 경험이 나빠집니다
