# 프로젝트 할 일 목록

## 🚀 Phase 1: 인프라 설정

### 도메인 & 배포
- [ ] Namecheap에서 도메인 구매 (gnajournal.com)
- [ ] GitHub 저장소 생성 및 연결
- [ ] Railway 계정 생성 및 프로젝트 설정
- [ ] Railway에 PostgreSQL 추가
- [ ] 도메인 연결 (Railway → Namecheap DNS 설정)

### Docker 설정
- [ ] `docker/Dockerfile` 생성 (멀티스테이지 빌드)
- [ ] `docker-compose.yml` 생성 (로컬 개발용)
- [ ] `.dockerignore` 생성
- [ ] Shadow JAR 플러그인 추가 (`build.gradle.kts`)
- [ ] 로컬에서 docker-compose 테스트

---

## 🗄️ Phase 2: 데이터베이스 & 모델

### PostgreSQL 전환
- [ ] H2 → PostgreSQL 드라이버 변경
- [ ] `application.yaml` 환경변수 설정
- [ ] 데이터베이스 연결 테스트

### 테이블 생성
- [ ] Users 테이블 (ERD 참고)
- [ ] Posts 테이블
- [ ] Categories 테이블
- [ ] Tags 테이블
- [ ] PostTags 테이블 (N:M)
- [ ] Comments 테이블 (선택)

### Repository 구현
- [ ] UserRepository
- [ ] PostRepository
- [ ] CategoryRepository
- [ ] TagRepository

### Koin DI 설정
- [ ] Koin 의존성 추가
- [ ] AppModule 정의
- [ ] Application에 Koin 설치

---

## 🔐 Phase 3: 인증

### 세션 기반 인증
- [ ] UserSession 데이터 클래스
- [ ] 로그인/로그아웃 라우트
- [ ] 비밀번호 해싱 (BCrypt)

### OAuth 소셜 로그인
- [ ] Google OAuth 설정 (Google Cloud Console)
- [ ] Kakao OAuth 설정 (Kakao Developers)
- [ ] Naver OAuth 설정 (Naver Developers)
- [ ] GitHub OAuth 설정 (선택)
- [ ] OAuth 콜백 처리 구현

### 권한 관리
- [ ] 어드민 권한 체크 미들웨어
- [ ] 인증 필요 라우트 보호

---

## 📝 Phase 4: 글 관리 (어드민)

### 어드민 라우트
- [ ] `GET /admin` - 대시보드
- [ ] `GET /admin/posts` - 글 목록
- [ ] `GET /admin/posts/new` - 새 글 폼
- [ ] `POST /admin/posts` - 글 생성
- [ ] `GET /admin/posts/:id/edit` - 수정 폼
- [ ] `PUT /admin/posts/:id` - 글 수정
- [ ] `DELETE /admin/posts/:id` - 글 삭제

### 마크다운 에디터
- [ ] Toast UI Editor 또는 SimpleMDE 선택
- [ ] 에디터 페이지 구현
- [ ] 마크다운 → HTML 변환 (서버)

### 이미지 업로드
- [ ] Cloudflare R2 계정 설정
- [ ] 이미지 업로드 API (`POST /admin/upload`)
- [ ] 에디터에서 드래그 앤 드롭 지원

### 카테고리/태그 관리
- [ ] 카테고리 CRUD
- [ ] 태그 자동완성

---

## 🌐 Phase 5: 공개 페이지

### 페이지 구현
- [ ] `GET /` - 홈페이지
- [ ] `GET /posts` - 글 목록
- [ ] `GET /posts/:slug` - 글 상세
- [ ] `GET /tags` - 태그 목록
- [ ] `GET /tags/:slug` - 태그별 글
- [ ] `GET /categories/:slug` - 카테고리별 글
- [ ] `GET /search` - 검색 결과
- [ ] `GET /about` - 소개 페이지

### 템플릿 (kotlinx.html)
- [ ] 공통 레이아웃 컴포넌트
- [ ] 네비게이션 바
- [ ] 푸터
- [ ] 글 카드 컴포넌트
- [ ] 페이지네이션 컴포넌트

### Tailwind CSS
- [ ] Tailwind 설치 및 설정
- [ ] 반응형 레이아웃 구현
- [ ] 다크모드 (선택)

---

## 🔍 Phase 6: SEO & 분석

### SEO
- [ ] `GET /sitemap.xml` - 동적 사이트맵
- [ ] `GET /robots.txt`
- [ ] `GET /rss` - RSS 피드
- [ ] Open Graph 메타 태그
- [ ] Google Search Console 등록

### 분석
- [ ] Umami 셀프호스팅 또는 조회수 직접 구현
- [ ] 조회수 카운터 (중복 방지)

### 댓글
- [ ] Giscus 설정 (GitHub Discussions)
- [ ] 또는 직접 구현

---

## 🧪 테스트

### 단위 테스트
- [ ] Service 테스트 (Kotest + MockK)
- [ ] Repository 테스트

### 통합 테스트
- [ ] API 라우트 테스트
- [ ] 인증 흐름 테스트

---

## 📋 기타

### 문서
- [ ] README.md 작성
- [ ] API 문서 업데이트
- [ ] 배포 가이드

### CI/CD (선택)
- [ ] GitHub Actions 워크플로우
- [ ] 자동 테스트
- [ ] Railway 자동 배포

---

## 우선순위 요약

1. **즉시**: GitHub 저장소 생성, 도메인 구매
2. **이번 주**: Docker 설정, PostgreSQL 전환
3. **다음 주**: 인증, 어드민 글 관리
4. **이후**: 공개 페이지, SEO, 분석