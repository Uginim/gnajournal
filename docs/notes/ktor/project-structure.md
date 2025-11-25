# Ktor 프로젝트 구조

## 개요

Ktor는 JetBrains에서 만든 Kotlin 비동기 웹 프레임워크이다. 가볍고 유연하며, 필요한 기능만 플러그인으로 추가하는 방식이다.

## 현재 프로젝트 파일 구조

```
src/main/kotlin/
├── Application.kt      # 애플리케이션 진입점
├── Routing.kt          # 라우팅 및 StatusPages 설정
├── Serialization.kt    # JSON 직렬화 설정
├── Security.kt         # 세션/인증 설정
├── HTTP.kt             # Compression, CORS, CachingHeaders
├── Monitoring.kt       # 로깅 설정
├── Databases.kt        # DB 연결 및 라우트
└── UsersSchema.kt      # Exposed 테이블/서비스 정의
```

## Application.kt - 진입점

```kotlin
fun main(args: Array<String>) {
    io.ktor.server.netty.EngineMain.main(args)
}

fun Application.module() {
    configureSerialization()
    configureDatabases()
    configureMonitoring()
    configureSecurity()
    configureHTTP()
    configureRouting()
}
```

### 핵심 개념

| 요소 | 설명 |
|-----|------|
| `EngineMain` | Netty 서버 엔진으로 애플리케이션 실행 |
| `Application.module()` | 확장 함수로 모듈 정의 |
| `configure*()` | 각 기능별 설정 함수 (관습적 네이밍) |

### 실행 흐름

1. `main()` → `EngineMain.main()` 호출
2. `application.yaml`에서 설정 읽음
3. `module()` 함수 실행
4. 각 `configure*()` 함수에서 플러그인 설치
5. 서버 시작

## 플러그인 시스템

Ktor는 **플러그인(Plugin)** 기반 아키텍처이다.

```kotlin
fun Application.configureHTTP() {
    install(Compression)  // 플러그인 설치
    install(CORS) {       // 설정과 함께 설치
        // 설정...
    }
}
```

### install() 함수

- 플러그인을 애플리케이션에 추가
- 중괄호 블록으로 설정 전달 가능
- 같은 플러그인 두 번 설치 불가

## 확장 함수 패턴

Ktor는 Kotlin의 **확장 함수**를 적극 활용한다.

```kotlin
// Application의 확장 함수로 정의
fun Application.configureRouting() {
    // this = Application 인스턴스
    install(StatusPages) { ... }
    routing { ... }
}
```

### 장점

- 모듈화: 기능별로 파일 분리 가능
- 테스트 용이: 각 함수 독립적으로 테스트
- 가독성: 관심사 분리

## build.gradle.kts 의존성

```kotlin
dependencies {
    // 서버 코어
    implementation("io.ktor:ktor-server-core")
    implementation("io.ktor:ktor-server-netty")  // 엔진

    // 플러그인들
    implementation("io.ktor:ktor-server-content-negotiation")  // JSON
    implementation("io.ktor:ktor-server-status-pages")         // 에러 처리
    implementation("io.ktor:ktor-server-call-logging")         // 로깅
    implementation("io.ktor:ktor-server-auth")                 // 인증
    implementation("io.ktor:ktor-server-sessions")             // 세션
    implementation("io.ktor:ktor-server-compression")          // 압축
    implementation("io.ktor:ktor-server-caching-headers")      // 캐시
    implementation("io.ktor:ktor-server-cors")                 // CORS

    // 직렬화
    implementation("io.ktor:ktor-serialization-kotlinx-json")

    // 데이터베이스
    implementation("org.jetbrains.exposed:exposed-core")
    implementation("org.jetbrains.exposed:exposed-jdbc")
    implementation("com.h2database:h2")
}
```

## 설정 파일

### application.yaml

```yaml
ktor:
  application:
    modules:
      - com.gnajournal.blog.ApplicationKt.module  # 모듈 경로
  deployment:
    port: 8080
```

- `modules`: 실행할 모듈 함수 지정
- `deployment`: 서버 설정 (포트 등)