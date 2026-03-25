# GitHub 연동 자동 배포 + PR Preview 설정

## 개요

GitHub 저장소와 Cloudflare Pages를 연동하면:
- **main에 push** → 프로덕션 자동 배포 (gnajournal.pages.dev)
- **PR 생성** → preview URL 자동 생성 (PR 코멘트에 URL 표시)

## 설정 방법

### 1단계: Cloudflare 대시보드 접속

1. https://dash.cloudflare.com 로그인
2. 좌측 메뉴 **Workers & Pages** 클릭
3. **gnajournal** 프로젝트 클릭

### 2단계: Git 연결

1. **Settings** 탭 클릭
2. **Builds & Deployments** 섹션
3. **Connect Git** 버튼 클릭
4. GitHub 계정 인증 (처음이면 Cloudflare 앱 설치 허용)
5. `Uginim/gnajournal` 저장소 선택

### 3단계: 빌드 설정

| 항목 | 값 |
|------|-----|
| Production branch | `main` |
| Framework preset | **Astro** |
| Build command | `npm run build` |
| Build output directory | `dist` |

### 4단계: 환경 변수 추가

Environment variables 섹션에서:

| 변수명 | 값 |
|--------|-----|
| `NODE_VERSION` | `22` |

### 5단계: 저장

**Save and Deploy** 클릭.

## 사용 방법

### 일반 배포 (main에 직접 push)

```bash
# 글 작성 후
git add src/content/blog/새글.md
git commit -m "새 글: 제목"
git push
```

1~2분 후 자동 배포됩니다.

### PR Preview (변경사항 미리보기)

```bash
# 새 브랜치에서 작업
git checkout -b post/새글제목
# 글 작성...
git add .
git commit -m "새 글 작성: 제목"
git push -u origin post/새글제목
```

GitHub에서 PR을 생성하면:
1. Cloudflare가 자동으로 preview 빌드 시작
2. PR 코멘트에 preview URL이 달림 (예: `abc123.gnajournal.pages.dev`)
3. preview URL에서 변경사항을 미리 확인
4. 확인 후 PR merge → 프로덕션 자동 배포

### 브랜치 네이밍 예시

```
post/블로그-시작하며      # 새 글
fix/타이포-수정           # 수정
feat/댓글-기능-추가       # 기능 추가
```

## 확인

설정 완료 후 Cloudflare 대시보드 > gnajournal > **Deployments** 탭에서 배포 이력을 확인할 수 있습니다.
