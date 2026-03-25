# 조회 통계 설정 가이드

두 가지 분석 도구를 함께 사용하는 것을 권장합니다.

## Google Analytics (GA4)

상세한 방문자 분석 + 향후 AdSense 연동에 유리합니다.

### 설정 방법

1. https://analytics.google.com/ 접속
2. 계정 및 속성 생성
3. 데이터 스트림 > 웹 선택
4. 사이트 URL 입력
5. **측정 ID** 확인 (`G-XXXXXXXXXX` 형태)

### 코드 적용

`src/components/BaseHead.astro`에서 GA 관련 주석을 해제하고 측정 ID를 교체:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-본인측정ID"></script>
<script is:inline>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', 'G-본인측정ID');
</script>
```

> 두 곳의 `G-XXXXXXXXXX`를 모두 교체해야 합니다.

### 확인할 수 있는 데이터

- 실시간 방문자 수
- 페이지별 조회수
- 유입 경로 (검색엔진, SNS, 직접 접속)
- 방문자 위치, 기기, 브라우저
- 체류 시간
- 인기 글 순위

## Cloudflare Web Analytics

Cloudflare Pages로 배포하면 자연스럽게 사용할 수 있습니다. 개인정보 친화적이고 가볍습니다.

### 설정 방법

1. Cloudflare 대시보드 > Web Analytics
2. 사이트 추가
3. **beacon 토큰** 복사

### 코드 적용

`src/components/BaseHead.astro`에서 CF 관련 주석을 해제하고 토큰을 교체:

```html
<script defer src='https://static.cloudflareinsights.com/beacon.min.js' data-cf-beacon='{"token": "본인토큰"}'></script>
```

### 확인할 수 있는 데이터

- 페이지 조회수
- 방문자 수 (유니크)
- 상위 페이지
- 유입 경로
- 국가별 방문자
- Core Web Vitals (성능 지표)

## GA vs Cloudflare 비교

| 항목 | Google Analytics | Cloudflare |
|------|-----------------|------------|
| 데이터 상세도 | 매우 상세 | 기본적 |
| 개인정보 | 쿠키 사용 | 쿠키 없음 |
| 실시간 | 지원 | 미지원 |
| AdSense 연동 | 가능 | 불가 |
| 사이트 속도 영향 | 약간 있음 | 거의 없음 |

**둘 다 사용하는 것을 권장**: GA는 상세 분석용, Cloudflare는 가벼운 트래픽 모니터링용.
