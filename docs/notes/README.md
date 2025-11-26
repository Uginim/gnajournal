# 학습 노트

블로그 프로젝트를 진행하며 배운 내용을 분야별로 정리합니다.

## 폴더 구조

```
notes/
├── java/          # Java/JVM 관련
├── kotlin/        # Kotlin 언어
├── ktor/          # Ktor 프레임워크
├── database/      # DB, SQL, Exposed ORM
├── web/           # HTML, CSS, HTTP, 웹 개념
└── devops/        # Docker, 배포, CI/CD
```

## 목차

### Java
- [Class File Version](./java/class-file-version.md) - Java 클래스 파일 버전과 호환성
- [Language Level](./java/language-level.md) - 컴파일러가 허용하는 문법 버전
- [JDK Distributions](./java/jdk-distributions.md) - OpenJDK, Corretto 등 배포판 비교
- [IntelliJ JDK Settings](./java/intellij-jdk-settings.md) - IDE에서 JDK 설정하는 방법
- [JVM Toolchain](./java/jvm-toolchain.md) - Gradle jvmToolchain 설정

### Kotlin
- [Idiomatic Kotlin](./kotlin/idiomatic-kotlin.md) - 코틀린스러운 코딩 방법
- [Lint & Formatting](./kotlin/lint-and-formatting.md) - ktlint, detekt 설정
- [Dependency Injection](./kotlin/dependency-injection.md) - Koin, Kodein 등 DI 프레임워크
- [TDD with Kotest](./kotlin/tdd-with-kotest.md) - Kotest 테스트 프레임워크와 TDD
- [Architecture Patterns](./kotlin/architecture-patterns.md) - Kotlin 아키텍처 패턴

### Ktor
- [Project Structure](./ktor/project-structure.md) - Ktor 프로젝트 구조와 실행 흐름
- [Plugins Overview](./ktor/plugins-overview.md) - 플러그인 시스템과 현재 설치된 플러그인
- [Routing](./ktor/routing.md) - 라우팅, 파라미터, 요청/응답 처리
- [Server Engines](./ktor/server-engines.md) - Netty, CIO 등 서버 엔진 비교
- [Static Files](./ktor/static-files.md) - 정적 파일 서빙 설정
- [OAuth Social Login](./ktor/oauth-social-login.md) - Google, Kakao, Naver OAuth 설정

### Database
- [Exposed ORM](./database/exposed-orm.md) - Kotlin ORM, 테이블 정의, CRUD
- [Exposed DSL vs DAO](./database/exposed-dsl-vs-dao.md) - 두 방식의 상세 비교

### Web
- [Comment System](./web/comment-system.md) - 댓글 시스템 (Giscus, 직접 구현)
- [Analytics](./web/analytics.md) - 통계/분석 도구 (Umami, GA)
- [Sitemap & SEO](./web/sitemap-seo.md) - Sitemap, RSS, Open Graph
- [Markdown Editor](./web/markdown-editor.md) - Milkdown, TipTap 등 에디터 비교

### DevOps
- [Docker Setup](./devops/docker-setup.md) - Docker, docker-compose 프로젝트 구성
- [Namecheap Domain](./devops/namecheap-domain.md) - 도메인 구매 및 DNS 설정
- [Cloud Hosting](./devops/cloud-hosting.md) - Fly.io, Railway 등 호스팅 비교
- [Media Storage](./devops/media-storage.md) - Cloudflare R2 이미지 저장소