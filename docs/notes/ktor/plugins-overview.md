# Ktor 플러그인 개요

## 플러그인이란?

Ktor의 **플러그인(Plugin)**은 애플리케이션에 기능을 추가하는 모듈이다. Spring의 Auto-Configuration과 비슷하지만, 더 명시적이고 가볍다.

## 설치 방법

```kotlin
fun Application.configure() {
    // 기본 설치
    install(Compression)

    // 설정과 함께 설치
    install(CORS) {
        anyHost()
        allowMethod(HttpMethod.Put)
    }
}
```

## 현재 프로젝트에 설치된 플러그인

| 플러그인 | 파일 | 용도 |
|---------|------|------|
| StatusPages | Routing.kt | 에러 처리 |
| Sessions | Security.kt | 세션 관리 |
| Compression | HTTP.kt | 응답 압축 (gzip) |
| CachingHeaders | HTTP.kt | HTTP 캐시 헤더 |
| CORS | HTTP.kt | Cross-Origin 요청 허용 |
| CallLogging | Monitoring.kt | 요청 로깅 |

## 플러그인 상세

### 1. StatusPages - 에러 처리

```kotlin
install(StatusPages) {
    exception<Throwable> { call, cause ->
        call.respondText(
            text = "500: $cause",
            status = HttpStatusCode.InternalServerError
        )
    }
}
```

- 예외 발생 시 커스텀 응답 반환
- `exception<T>`: 특정 예외 타입 처리
- `status(HttpStatusCode)`: 특정 상태 코드 처리

### 2. Sessions - 세션 관리

```kotlin
install(Sessions) {
    cookie<MySession>("MY_SESSION") {
        cookie.extensions["SameSite"] = "lax"
    }
}

@Serializable
data class MySession(val count: Int = 0)
```

- 쿠키 기반 세션 저장
- `@Serializable` 데이터 클래스로 세션 데이터 정의
- `SameSite`: CSRF 방지 설정

**사용법:**
```kotlin
// 세션 읽기
val session = call.sessions.get<MySession>() ?: MySession()

// 세션 저장
call.sessions.set(session.copy(count = session.count + 1))
```

### 3. Compression - 응답 압축

```kotlin
install(Compression)
```

- 응답을 gzip/deflate로 압축
- 클라이언트가 `Accept-Encoding: gzip` 보내면 자동 적용
- 네트워크 대역폭 절약

### 4. CachingHeaders - HTTP 캐시

```kotlin
install(CachingHeaders) {
    options { call, outgoingContent ->
        when (outgoingContent.contentType?.withoutParameters()) {
            ContentType.Text.CSS -> CachingOptions(
                CacheControl.MaxAge(maxAgeSeconds = 24 * 60 * 60)  // 24시간
            )
            else -> null
        }
    }
}
```

- 응답에 `Cache-Control` 헤더 추가
- 정적 파일(CSS, JS, 이미지) 캐싱에 유용
- `maxAgeSeconds`: 브라우저 캐시 유지 시간

### 5. CORS - Cross-Origin Resource Sharing

```kotlin
install(CORS) {
    allowMethod(HttpMethod.Options)
    allowMethod(HttpMethod.Put)
    allowMethod(HttpMethod.Delete)
    allowMethod(HttpMethod.Patch)
    allowHeader(HttpHeaders.Authorization)
    allowHeader("MyCustomHeader")
    anyHost()  // 주의: 프로덕션에서는 제한 필요
}
```

- 다른 도메인에서의 API 호출 허용
- SPA(React, Vue 등)에서 백엔드 API 호출 시 필요
- `anyHost()`: 모든 도메인 허용 (개발용)

### 6. CallLogging - 요청 로깅

```kotlin
install(CallLogging) {
    level = Level.INFO
    filter { call -> call.request.path().startsWith("/") }
}
```

- 모든 HTTP 요청을 로그로 기록
- `level`: 로그 레벨 (DEBUG, INFO 등)
- `filter`: 로깅할 요청 필터링

**출력 예시:**
```
INFO  - 200 OK: GET - /users/1
INFO  - 201 Created: POST - /users
```

## 플러그인 vs 미들웨어

| | Ktor 플러그인 | Express 미들웨어 |
|--|-------------|-----------------|
| 설치 | `install()` | `app.use()` |
| 순서 | 설치 순서 중요 | 등록 순서 중요 |
| 범위 | 전체 애플리케이션 | 라우트별 가능 |

## 플러그인 실행 순서

`Application.module()`에서 호출하는 순서대로 실행된다.

```kotlin
fun Application.module() {
    configureSerialization()  // 1번
    configureDatabases()      // 2번
    configureMonitoring()     // 3번
    configureSecurity()       // 4번
    configureHTTP()           // 5번
    configureRouting()        // 6번
}
```

일반적으로:
1. 직렬화 (JSON 파싱)
2. 데이터베이스 연결
3. 로깅/모니터링
4. 인증/보안
5. HTTP 설정 (압축, CORS)
6. 라우팅 (마지막)