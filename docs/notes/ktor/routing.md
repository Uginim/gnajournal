# Ktor 라우팅

## 기본 개념

라우팅은 HTTP 요청을 적절한 핸들러로 연결하는 것이다.

```kotlin
fun Application.configureRouting() {
    routing {
        get("/") {
            call.respondText("Hello World!")
        }
    }
}
```

## HTTP 메서드

```kotlin
routing {
    get("/users") { }      // 조회
    post("/users") { }     // 생성
    put("/users/{id}") { } // 전체 수정
    patch("/users/{id}") { } // 부분 수정
    delete("/users/{id}") { } // 삭제
}
```

## 경로 파라미터

```kotlin
get("/users/{id}") {
    val id = call.parameters["id"]  // String?
    val idInt = call.parameters["id"]?.toInt()
        ?: throw IllegalArgumentException("Invalid ID")
}
```

- `{id}`: 경로 변수 정의
- `call.parameters["id"]`: 변수 값 읽기 (nullable)

## 쿼리 파라미터

```kotlin
// GET /search?q=kotlin&page=1
get("/search") {
    val query = call.request.queryParameters["q"]
    val page = call.request.queryParameters["page"]?.toInt() ?: 1
}
```

## 요청 본문 읽기

```kotlin
post("/users") {
    val user = call.receive<ExposedUser>()  // JSON → 객체
    // user.name, user.age 사용
}
```

- `call.receive<T>()`: 요청 본문을 타입 T로 역직렬화
- Content-Negotiation 플러그인 필요

## 응답 보내기

### 텍스트 응답

```kotlin
get("/") {
    call.respondText("Hello World!")
}
```

### JSON 응답

```kotlin
get("/users/{id}") {
    val user = userService.read(id)
    call.respond(HttpStatusCode.OK, user)  // 객체 → JSON
}
```

### 상태 코드

```kotlin
post("/users") {
    val id = userService.create(user)
    call.respond(HttpStatusCode.Created, id)  // 201
}

get("/users/{id}") {
    val user = userService.read(id)
    if (user != null) {
        call.respond(HttpStatusCode.OK, user)      // 200
    } else {
        call.respond(HttpStatusCode.NotFound)      // 404
    }
}
```

## 라우트 그룹화

```kotlin
routing {
    route("/api") {
        route("/users") {
            get { }           // GET /api/users
            post { }          // POST /api/users
            get("/{id}") { }  // GET /api/users/{id}
        }
    }
}
```

## 현재 프로젝트의 라우트

### Routing.kt
```kotlin
get("/") {
    call.respondText("Hello World!")
}
```

### Databases.kt
```kotlin
post("/users") { }      // 사용자 생성
get("/users/{id}") { }  // 사용자 조회
put("/users/{id}") { }  // 사용자 수정
delete("/users/{id}") { } // 사용자 삭제
```

### Security.kt
```kotlin
get("/session/increment") { }  // 세션 카운터 증가
```

### Serialization.kt
```kotlin
get("/json/kotlinx-serialization") { }  // JSON 테스트
```

## call 객체

`call`은 현재 HTTP 요청/응답을 나타낸다.

```kotlin
get("/example") {
    // 요청 정보
    call.request.path()                    // "/example"
    call.request.httpMethod                // GET
    call.request.headers["Authorization"]  // 헤더 읽기
    call.parameters["id"]                  // 경로 파라미터
    call.request.queryParameters["q"]      // 쿼리 파라미터

    // 응답
    call.respond(status, body)             // JSON 응답
    call.respondText("text")               // 텍스트 응답
    call.respondRedirect("/other")         // 리다이렉트
}
```

## 주의사항

- 라우트 핸들러는 **suspend 함수** (코루틴)
- `call.receive<T>()`는 한 번만 호출 가능
- 경로는 대소문자 구분함