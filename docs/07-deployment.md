# 배포 가이드 (Cloudflare Pages)

## 왜 Cloudflare Pages인가

- 무제한 요청, 무제한 대역폭 (무료)
- 광고 수익에 대한 제한 없음
- 전 세계 CDN으로 빠른 로딩
- 커스텀 도메인 무료
- Web Analytics 무료 제공

## 1단계: GitHub 저장소 준비

```bash
cd /Users/kimenugi/workspace/dev/gnajournal/gnajournal-astro
git init
git add .
git commit -m "Initial commit: 그나저나 블로그"
```

GitHub에 저장소를 생성하고 push:

```bash
git remote add origin https://github.com/USERNAME/gnajournal.git
git push -u origin main
```

## 2단계: Cloudflare Pages 연결

1. https://dash.cloudflare.com/ 접속 (회원가입 필요)
2. 좌측 메뉴 > **Workers & Pages** 선택
3. **Create** > **Pages** 탭 > **Connect to Git**
4. GitHub 계정 연결 및 저장소 선택

## 3단계: 빌드 설정

| 항목 | 값 |
|------|-----|
| Framework preset | Astro |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Node.js version | 22 (Environment variables에 `NODE_VERSION` = `22` 추가) |

## 4단계: 배포

"Save and Deploy" 클릭하면 자동 빌드 및 배포됩니다.
완료 후 `프로젝트명.pages.dev` 도메인이 할당됩니다.

## 자동 배포

설정 후에는 GitHub에 push할 때마다 자동으로 빌드 + 배포됩니다.

```bash
# 새 글 작성 후
git add src/content/blog/new-post.md
git commit -m "새 글 추가: 제목"
git push
```

push하면 1~2분 내에 사이트에 반영됩니다.

## 커스텀 도메인 연결 (선택)

1. Cloudflare Pages 프로젝트 > Custom domains
2. 도메인 입력 (예: `blog.example.com`)
3. DNS 설정 안내에 따라 CNAME 레코드 추가
4. SSL 인증서 자동 발급 (몇 분 소요)

### Astro 설정 업데이트

커스텀 도메인을 연결하면 `astro.config.mjs`의 site를 업데이트:

```javascript
export default defineConfig({
    site: 'https://blog.example.com',  // 실제 도메인으로 변경
    integrations: [mdx(), sitemap()],
});
```

이 값은 RSS 피드, 사이트맵, OG 이미지 등에 사용됩니다.

## 환경 변수 설정 (필요 시)

Cloudflare Pages 대시보드 > Settings > Environment variables 에서 추가할 수 있습니다.
현재 프로젝트에서는 별도의 환경 변수가 필요하지 않습니다.

## 트러블슈팅

### 빌드 실패 시

- Cloudflare 대시보드에서 빌드 로그를 확인
- `NODE_VERSION` 환경 변수가 `22`로 설정되어 있는지 확인
- 로컬에서 `npm run build`가 성공하는지 확인

### 페이지가 404인 경우

- `dist/` 폴더에 해당 HTML이 생성되었는지 확인
- Build output directory가 `dist`로 설정되어 있는지 확인
