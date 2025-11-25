# Ktor 블로그 기술 스택

Kotlin + Ktor 기반 블로그 프로젝트의 기술 스택 정리 문서입니다.

---

## 개요

| 항목 | 선택 |
|------|------|
| **언어** | Kotlin |
| **프레임워크** | Ktor |
| **프론트엔드** | Ktor HTML DSL + Tailwind CSS |
| **데이터베이스** | PostgreSQL (Supabase) |
| **배포** | Railway → Oracle Cloud |

---

## 백엔드

### 코어

| 기술 | 버전 | 라이선스 | 용도 |
|------|------|---------|------|
| Kotlin | 1.9.x | Apache 2.0 | 언어 |
| Ktor | 2.3.x | Apache 2.0 | 웹 프레임워크 |
| Gradle (Kotlin DSL) | 8.x | Apache 2.0 | 빌드 도구 |
| Netty | - | Apache 2.0 | 서버 엔진 |

### Ktor 플러그인

| 플러그인 | 용도 |
|---------|------|
| `ktor-server-core` | 코어 |
| `ktor-server-netty` | 서버 엔진 |
| `ktor-server-routing` | URL 라우팅 |
| `ktor-server-auth` | 인증 |
| `ktor-server-sessions` | 세션 관리 |
| `ktor-server-content-negotiation` | JSON 처리 |
| `ktor-serialization-kotlinx-json` | JSON 직렬화 |
| `ktor-server-html-builder` | HTML DSL |
| `ktor-server-compression` | Gzip 압축 |
| `ktor-server-caching-headers` | 캐시 헤더 |
| `ktor-server-status-pages` | 에러 처리 |
| `ktor-server-cors` | CORS |

---

## 프론트엔드

### 렌더링

| 기술 | 용도 | 선택 이유 |
|------|------|----------|
| **Ktor HTML DSL** | SSR HTML 렌더링 | 타입 안전, Kotlin 네이티브 |
| **kotlinx-html** | HTML DSL 라이브러리 | Ktor 공식 지원 |

### 스타일링 & UI

| 기술 | 용도 | CDN/설치 |
|------|------|---------|
| **Tailwind CSS** | 유틸리티 CSS | CDN |
| **HTMX** | 동적 UI (AJAX 대체) | CDN |
| **Prism.js** | 코드 하이라이팅 | CDN |
| **Toast UI Editor** | 마크다운 에디터 | CDN |

### CDN 링크

```html
<!-- Tailwind CSS -->
<script src="https://cdn.tailwindcss.com"></script>

<!-- HTMX -->
<script src="https://unpkg.com/htmx.org@1.9.10"></script>

<!-- Prism.js (코드 하이라이팅) -->
<link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-kotlin.min.js"></script>

<!-- Toast UI Editor -->
<link rel="stylesheet" href="https://uicdn.toast.com/editor/latest/toastui-editor.min.css">
<script src="https://uicdn.toast.com/editor/latest/toastui-editor-all.min.js"></script>
```

---

## 데이터베이스

### ORM & 연결

| 기술 | 버전 | 라이선스 | 용도 |
|------|------|---------|------|
| Exposed (Core) | 0.46.x | Apache 2.0 | ORM/쿼리빌더 |
| Exposed (DAO) | 0.46.x | Apache 2.0 | DAO 패턴 |
| Exposed (Java Time) | 0.46.x | Apache 2.0 | 날짜/시간 |
| HikariCP | 5.x | Apache 2.0 | 커넥션 풀 |
| PostgreSQL Driver | 42.x | BSD-2 | DB 드라이버 |

### 호스팅 옵션

| 서비스 | 무료 용량 | 추천 |
|--------|----------|------|
| **Supabase** | 500MB | 개발/소규모 ⭐ |
| **Neon** | 512MB | 서버리스 |
| **Railway** | $5 크레딧 내 | 앱과 함께 |
| **Oracle Cloud** | 20GB x 2 | 프로덕션 ⭐ |

### 데이터 모델

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  users  │     │  posts  │────▶│  tags   │
└─────────┘     └─────────┘     └─────────┘
     │               │               │
     │               │          ┌────┴────┐
     │               ▼          │post_tags│
     │          ┌─────────┐     └─────────┘
     └─────────▶│comments │
                └─────────┘
                     │
                ┌────┴────┐
                │categories│
                └─────────┘
```

---

## 라이브러리

### 필수

| 라이브러리 | 버전 | 라이선스 | 용도 |
|-----------|------|---------|------|
| `commonmark` | 0.21.x | BSD | 마크다운 → HTML |
| `commonmark-ext-gfm-tables` | 0.21.x | BSD | 테이블 확장 |
| `commonmark-ext-autolink` | 0.21.x | BSD | 자동 링크 |
| `commonmark-ext-heading-anchor` | 0.21.x | BSD | 목차 앵커 |
| `caffeine` | 3.1.x | Apache 2.0 | 인메모리 캐시 |
| `jbcrypt` | 0.4 | ISC | 비밀번호 해싱 |
| `logback-classic` | 1.4.x | EPL/LGPL | 로깅 |

### 선택

| 라이브러리 | 버전 | 라이선스 | 용도 |
|-----------|------|---------|------|
| `konform` | 0.4.x | MIT | 입력 검증 |
| `lucene-core` | 9.x | Apache 2.0 | 전문 검색 |
| `scrimage-core` | 4.x | Apache 2.0 | 이미지 처리 |

---

## 인프라 & 배포

### 개발 단계

| 서비스 | 용도 | 비용 |
|--------|------|------|
| **Railway** | 앱 호스팅 | 무료 $5/월 |
| **Supabase** | PostgreSQL | 무료 500MB |
| **Cloudinary** | 이미지 저장 | 무료 25GB |

### 프로덕션 단계 (권장)

| 서비스 | 용도 | 비용 |
|--------|------|------|
| **Oracle Cloud** | VM (ARM 4코어/24GB) | 평생 무료 |
| **Oracle Autonomous DB** | PostgreSQL 호환 | 무료 20GB |
| **Cloudflare** | CDN, SSL | 무료 |

### 외부 서비스

| 서비스 | 용도 | 비용 |
|--------|------|------|
| **Giscus** | 댓글 (GitHub 기반) | 무료 |
| **Umami** | 방문자 분석 | 무료 (셀프호스팅) |
| **Google Analytics** | 방문자 분석 | 무료 |

---

## build.gradle.kts

```kotlin
plugins {
    kotlin("jvm") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    id("io.ktor.plugin") version "2.3.7"
}

group = "com.ulog"
version = "1.0.0"

repositories {
    mavenCentral()
}

val ktorVersion = "2.3.7"
val exposedVersion = "0.46.0"
val commonmarkVersion = "0.21.0"

dependencies {
    // ===== Ktor 서버 =====
    implementation("io.ktor:ktor-server-core:$ktorVersion")
    implementation("io.ktor:ktor-server-netty:$ktorVersion")
    implementation("io.ktor:ktor-server-auth:$ktorVersion")
    implementation("io.ktor:ktor-server-sessions:$ktorVersion")
    implementation("io.ktor:ktor-server-content-negotiation:$ktorVersion")
    implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")
    implementation("io.ktor:ktor-server-html-builder:$ktorVersion")
    implementation("io.ktor:ktor-server-compression:$ktorVersion")
    implementation("io.ktor:ktor-server-caching-headers:$ktorVersion")
    implementation("io.ktor:ktor-server-status-pages:$ktorVersion")
    implementation("io.ktor:ktor-server-cors:$ktorVersion")

    // ===== HTML DSL =====
    implementation("org.jetbrains.kotlinx:kotlinx-html-jvm:0.11.0")

    // ===== 데이터베이스 =====
    implementation("org.jetbrains.exposed:exposed-core:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-dao:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-jdbc:$exposedVersion")
    implementation("org.jetbrains.exposed:exposed-java-time:$exposedVersion")
    implementation("com.zaxxer:HikariCP:5.0.1")
    implementation("org.postgresql:postgresql:42.7.1")

    // ===== 마크다운 =====
    implementation("org.commonmark:commonmark:$commonmarkVersion")
    implementation("org.commonmark:commonmark-ext-gfm-tables:$commonmarkVersion")
    implementation("org.commonmark:commonmark-ext-autolink:$commonmarkVersion")
    implementation("org.commonmark:commonmark-ext-gfm-strikethrough:$commonmarkVersion")
    implementation("org.commonmark:commonmark-ext-heading-anchor:$commonmarkVersion")

    // ===== 유틸리티 =====
    implementation("com.github.ben-manes.caffeine:caffeine:3.1.8")
    implementation("org.mindrot:jbcrypt:0.4")
    implementation("io.konform:konform:0.4.0")

    // ===== 로깅 =====
    implementation("ch.qos.logback:logback-classic:1.4.14")

    // ===== 테스트 =====
    testImplementation("io.ktor:ktor-server-tests:$ktorVersion")
    testImplementation("io.kotest:kotest-runner-junit5:5.8.0")
    testImplementation("io.mockk:mockk:1.13.8")
    testImplementation("com.h2database:h2:2.2.224")
}

application {
    mainClass.set("com.ulog.ApplicationKt")
}

ktor {
    fatJar {
        archiveFileName.set("ulog-ktor.jar")
    }
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}
```

---

## 프로젝트 구조

```
ulog-ktor/
├── src/
│   ├── main/
│   │   ├── kotlin/com/ulog/
│   │   │   ├── Application.kt              # 메인 진입점
│   │   │   │
│   │   │   ├── plugins/                    # Ktor 플러그인 설정
│   │   │   │   ├── Routing.kt
│   │   │   │   ├── Security.kt
│   │   │   │   ├── Serialization.kt
│   │   │   │   ├── Database.kt
│   │   │   │   └── Caching.kt
│   │   │   │
│   │   │   ├── routes/                     # 라우트 핸들러
│   │   │   │   ├── HomeRoutes.kt
│   │   │   │   ├── PostRoutes.kt
│   │   │   │   ├── AuthRoutes.kt
│   │   │   │   ├── AdminRoutes.kt
│   │   │   │   ├── SearchRoutes.kt
│   │   │   │   └── SeoRoutes.kt            # sitemap, rss
│   │   │   │
│   │   │   ├── templates/                  # HTML DSL 컴포넌트
│   │   │   │   ├── Layout.kt               # 공통 레이아웃
│   │   │   │   ├── components/
│   │   │   │   │   ├── Nav.kt
│   │   │   │   │   ├── Footer.kt
│   │   │   │   │   ├── PostCard.kt
│   │   │   │   │   ├── Pagination.kt
│   │   │   │   │   ├── SearchBar.kt
│   │   │   │   │   ├── TagCloud.kt
│   │   │   │   │   └── Seo.kt              # 메타 태그
│   │   │   │   └── pages/
│   │   │   │       ├── HomePage.kt
│   │   │   │       ├── PostListPage.kt
│   │   │   │       ├── PostDetailPage.kt
│   │   │   │       ├── TagPage.kt
│   │   │   │       ├── SearchPage.kt
│   │   │   │       ├── SignInPage.kt
│   │   │   │       ├── SignUpPage.kt
│   │   │   │       └── admin/
│   │   │   │           ├── DashboardPage.kt
│   │   │   │           ├── PostEditorPage.kt
│   │   │   │           └── SettingsPage.kt
│   │   │   │
│   │   │   ├── models/                     # 데이터 모델 (Exposed)
│   │   │   │   ├── User.kt
│   │   │   │   ├── Post.kt
│   │   │   │   ├── Tag.kt
│   │   │   │   ├── Category.kt
│   │   │   │   └── Comment.kt
│   │   │   │
│   │   │   ├── repositories/               # 데이터 접근 계층
│   │   │   │   ├── UserRepository.kt
│   │   │   │   ├── PostRepository.kt
│   │   │   │   ├── TagRepository.kt
│   │   │   │   └── CommentRepository.kt
│   │   │   │
│   │   │   ├── services/                   # 비즈니스 로직
│   │   │   │   ├── AuthService.kt
│   │   │   │   ├── PostService.kt
│   │   │   │   ├── MarkdownService.kt
│   │   │   │   ├── SearchService.kt
│   │   │   │   └── CacheService.kt
│   │   │   │
│   │   │   └── utils/                      # 유틸리티
│   │   │       ├── PasswordUtil.kt
│   │   │       ├── DateUtil.kt
│   │   │       └── SlugUtil.kt
│   │   │
│   │   └── resources/
│   │       ├── application.conf            # 설정 파일
│   │       ├── logback.xml                 # 로깅 설정
│   │       └── static/                     # 정적 파일
│   │           ├── css/
│   │           ├── js/
│   │           └── images/
│   │
│   └── test/kotlin/com/ulog/
│       ├── ApplicationTest.kt
│       ├── routes/
│       └── repositories/
│
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
├── Dockerfile
├── docker-compose.yml
├── railway.json
└── README.md
```

---

## 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                        클라이언트                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ HTML DSL     │  │    HTMX      │  │ Toast UI Editor  │   │
│  │   (SSR)      │  │  (동적 UI)    │  │   (마크다운)      │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│                  Tailwind CSS + Prism.js                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Ktor 서버                              │
├─────────────────────────────────────────────────────────────┤
│  Routes                                                     │
│  ├── GET  /                    홈                           │
│  ├── GET  /post                글 목록                       │
│  ├── GET  /post/{id}           글 상세                       │
│  ├── GET  /post/{id}/{slug}    SEO 친화적 URL                │
│  ├── GET  /tag/{name}          태그별 글                     │
│  ├── GET  /search?q=           검색                         │
│  ├── GET  /signin              로그인 페이지                 │
│  ├── POST /signin              로그인 처리                   │
│  ├── GET  /signup              회원가입 페이지               │
│  ├── POST /signup              회원가입 처리                 │
│  ├── GET  /admin               어드민 대시보드               │
│  ├── GET  /admin/write         글 작성                      │
│  ├── POST /admin/write         글 저장                      │
│  ├── GET  /admin/edit/{id}     글 수정                      │
│  ├── GET  /sitemap.xml         사이트맵                     │
│  └── GET  /rss                 RSS 피드                     │
├─────────────────────────────────────────────────────────────┤
│  Services                                                   │
│  ├── PostService       글 CRUD, 페이지네이션                 │
│  ├── AuthService       로그인, 세션 관리                     │
│  ├── MarkdownService   MD → HTML 변환                       │
│  ├── SearchService     글 검색                              │
│  └── CacheService      캐시 관리                            │
├─────────────────────────────────────────────────────────────┤
│  Plugins                                                    │
│  ├── Authentication + Sessions                              │
│  ├── HTML Builder                                           │
│  ├── ContentNegotiation (JSON)                              │
│  ├── Compression (Gzip)                                     │
│  ├── CachingHeaders                                         │
│  └── StatusPages (에러 처리)                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      데이터 레이어                           │
├────────────────────────┬────────────────────────────────────┤
│     Exposed ORM        │         Caffeine Cache             │
├────────────────────────┴────────────────────────────────────┤
│                      PostgreSQL                             │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐   │
│  │ users  │ │ posts  │ │  tags  │ │comments│ │categories│   │
│  └────────┘ └────────┘ └────────┘ └────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       외부 서비스                            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐             │
│  │ Cloudinary │  │   Giscus   │  │   Umami    │             │
│  │  (이미지)   │  │   (댓글)    │  │   (분석)   │             │
│  └────────────┘  └────────────┘  └────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

---

## 비용 요약

### 개발 단계

| 서비스 | 월 비용 |
|--------|--------|
| Railway | $0 (무료 $5 내) |
| Supabase | $0 (무료 500MB) |
| Cloudinary | $0 (무료 25GB) |
| **총합** | **$0** |

### 프로덕션 단계 (Oracle Cloud)

| 서비스 | 월 비용 |
|--------|--------|
| Oracle Cloud VM | $0 (평생 무료) |
| Oracle Autonomous DB | $0 (무료 20GB) |
| Cloudflare | $0 (무료) |
| 도메인 (선택) | ~$1 |
| **총합** | **$0 ~ $1** |

---

## 참고 자료

- [Ktor 공식 문서](https://ktor.io/docs/)
- [Exposed 위키](https://github.com/JetBrains/Exposed/wiki)
- [kotlinx.html](https://github.com/Kotlin/kotlinx.html)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [HTMX](https://htmx.org/docs/)
- [Toast UI Editor](https://ui.toast.com/tui-editor)
