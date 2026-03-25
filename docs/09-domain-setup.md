# 커스텀 도메인 연결 (meeemo.net)

## 개요

현재 `gnajournal.pages.dev`로 접속 가능하지만, 커스텀 도메인 `meeemo.net`을 연결하면:
- 짧고 기억하기 쉬운 URL
- AdSense 승인에 유리
- 전문적인 인상

## 방법 1: 네임서버 변경 (권장)

가비아에서 네임서버를 Cloudflare로 변경하면 Cloudflare의 CDN + 보안 기능을 모두 사용할 수 있습니다.

### 1단계: Cloudflare에 도메인 추가

1. https://dash.cloudflare.com 로그인
2. **Add a site** 클릭
3. `meeemo.net` 입력
4. **Free** 플랜 선택
5. DNS 레코드 스캔 완료될 때까지 대기

### 2단계: 가비아에서 네임서버 변경

Cloudflare가 안내하는 네임서버 2개를 복사합니다 (예시):
```
ns1.cloudflare.com
ns2.cloudflare.com
```

가비아에서:
1. https://dns.gabia.com 로그인
2. meeemo.net > **관리** 클릭
3. **네임서버 설정** 메뉴
4. 기존 네임서버를 Cloudflare 네임서버로 변경
5. 저장

> 네임서버 변경은 전파에 최대 24~48시간 소요될 수 있습니다 (보통 1~2시간 내).

### 3단계: Cloudflare Pages에 도메인 연결

네임서버 전파 완료 후:

1. Cloudflare 대시보드 > Workers & Pages > **gnajournal**
2. **Custom domains** 탭
3. **Set up a custom domain** 클릭
4. `meeemo.net` 입력
5. CNAME 레코드 자동 생성 확인 후 **Activate domain**

`www.meeemo.net`도 추가하려면 같은 과정을 반복합니다.

### 4단계: astro.config.mjs 업데이트

```javascript
export default defineConfig({
    site: 'https://meeemo.net',  // 변경
    integrations: [mdx(), sitemap()],
});
```

이 값은 RSS, 사이트맵, OG 이미지 URL에 사용됩니다.

## 방법 2: CNAME만 설정 (간단)

네임서버를 변경하지 않고, 가비아 DNS에서 CNAME 레코드만 추가하는 방법입니다.

가비아 DNS 관리에서:
```
타입: CNAME
호스트: @  (또는 www)
값: gnajournal.pages.dev
```

> 이 방법은 Cloudflare CDN/보안 기능을 사용할 수 없습니다.

## SSL 인증서

Cloudflare가 자동으로 무료 SSL 인증서를 발급합니다.
- 네임서버 변경 후 자동 적용 (몇 분 소요)
- 별도 설정 불필요

## 도메인 갱신 비용 절약

현재 가비아에서 연 24,000원입니다. Cloudflare Registrar로 이전하면 연 ~15,000원으로 줄일 수 있습니다.

이전은 도메인 등록 후 60일이 지나야 가능하며, 갱신 시점에 하는 것이 가장 효율적입니다.

### Cloudflare로 도메인 이전

1. Cloudflare 대시보드 > **Domain Registration** > **Transfer**
2. `meeemo.net` 입력
3. 가비아에서 **도메인 잠금 해제** + **인증 코드(EPP)** 발급
4. Cloudflare에 인증 코드 입력
5. 결제 후 이전 완료 (보통 5~7일)
