# Kotlin DI (Dependency Injection)

## 개요

Spring처럼 Kotlin/Ktor에서도 DI를 사용할 수 있다. 대표적인 프레임워크로 **Koin**, Kodein, Dagger가 있다.

## DI 프레임워크 비교

| | Koin | Kodein | Dagger/Hilt |
|--|------|--------|-------------|
| 타입 | 런타임 | 런타임 | 컴파일 타임 |
| 학습 곡선 | 쉬움 | 중간 | 어려움 |
| 성능 | 좋음 | 좋음 | 최고 |
| Ktor 지원 | 공식 지원 | 지원 | 수동 설정 |
| 주 사용처 | Ktor, Android | 범용 | Android |

**Ktor에서는 Koin을 가장 많이 사용**한다.

---

## Koin

### 특징

- **DSL 기반**: Kotlin스러운 문법
- **경량**: 리플렉션 최소화
- **공식 Ktor 지원**: `koin-ktor` 모듈 제공
- **테스트 친화적**: 모킹 쉬움

### 의존성 추가

```kotlin
// build.gradle.kts
val koin_version = "3.5.0"

dependencies {
    implementation("io.insert-koin:koin-ktor:$koin_version")
    implementation("io.insert-koin:koin-logger-slf4j:$koin_version")
}
```

### 모듈 정의

```kotlin
// di/AppModule.kt
val appModule = module {
    // 싱글톤
    single { Database.connect(...) }

    // 싱글톤 (의존성 주입)
    single { UserRepository(get()) }  // get() = Database
    single { UserService(get()) }     // get() = UserRepository

    // 팩토리 (매번 새 인스턴스)
    factory { SomeController(get()) }
}
```

### Ktor에 설치

```kotlin
// Application.kt
fun Application.module() {
    install(Koin) {
        slf4jLogger()
        modules(appModule)
    }

    configureRouting()
}
```

### 사용하기

```kotlin
// 라우트에서 주입받기
fun Application.configureRouting() {
    val userService by inject<UserService>()

    routing {
        get("/users/{id}") {
            val user = userService.findById(call.parameters["id"]!!.toInt())
            call.respond(user)
        }
    }
}

// 또는 라우트 안에서
routing {
    get("/users") {
        val userService by inject<UserService>()
        call.respond(userService.findAll())
    }
}
```

### 전체 예시

```kotlin
// di/AppModule.kt
val appModule = module {
    single {
        Database.connect(
            url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1",
            driver = "org.h2.Driver"
        )
    }
    single { UserRepository(get()) }
    single { PostRepository(get()) }
    single { UserService(get()) }
    single { PostService(get(), get()) }
}

// Application.kt
fun Application.module() {
    install(Koin) {
        slf4jLogger()
        modules(appModule)
    }

    configureSerialization()
    configureRouting()
}

// routes/UserRoutes.kt
fun Application.configureUserRoutes() {
    val userService by inject<UserService>()

    routing {
        route("/users") {
            get { call.respond(userService.findAll()) }
            get("/{id}") {
                val id = call.parameters["id"]!!.toInt()
                call.respond(userService.findById(id))
            }
            post {
                val user = call.receive<CreateUserRequest>()
                call.respond(HttpStatusCode.Created, userService.create(user))
            }
        }
    }
}
```

---

## Koin vs Spring DI

| | Spring | Koin |
|--|--------|------|
| 설정 | 어노테이션 (`@Component`, `@Autowired`) | DSL (`module { }`, `single { }`) |
| 스캔 | 컴포넌트 스캔 (자동) | 명시적 등록 |
| 주입 | 필드/생성자 주입 | `get()`, `inject()` |
| 범위 | `@Singleton`, `@Prototype` | `single`, `factory` |

### Spring 스타일

```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;
}
```

### Koin 스타일

```kotlin
// 모듈에서 등록
val appModule = module {
    single { UserRepository() }
    single { UserService(get()) }
}

// 사용
val userService by inject<UserService>()
```

---

## 현재 프로젝트에 적용하려면?

### 1. 의존성 추가

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.insert-koin:koin-ktor:3.5.0")
    implementation("io.insert-koin:koin-logger-slf4j:3.5.0")
}
```

### 2. 모듈 정의

```kotlin
// di/AppModule.kt
package net.gnajournal.blog.di

import net.gnajournal.blog.UserService
import org.jetbrains.exposed.sql.Database
import org.koin.dsl.module

val appModule = module {
    single {
        Database.connect(
            url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1",
            user = "root",
            driver = "org.h2.Driver",
            password = ""
        )
    }
    single { UserService(get()) }
}
```

### 3. Application에 설치

```kotlin
// Application.kt
fun Application.module() {
    install(Koin) {
        slf4jLogger()
        modules(appModule)
    }

    configureSerialization()
    configureRouting()
    // ...
}
```

### 4. 라우트에서 사용

```kotlin
// Databases.kt
fun Application.configureDatabases() {
    val userService by inject<UserService>()

    routing {
        post("/users") {
            val user = call.receive<ExposedUser>()
            val id = userService.create(user)
            call.respond(HttpStatusCode.Created, id)
        }
        // ...
    }
}
```

---

## 왜 DI를 쓰는가?

### Before (현재 코드)

```kotlin
fun Application.configureDatabases() {
    val database = Database.connect(...)  // 직접 생성
    val userService = UserService(database)  // 직접 생성

    routing { ... }
}
```

**문제점:**
- 테스트 시 Mock 주입 어려움
- 의존성 변경 시 여러 곳 수정 필요
- 인스턴스 관리 (싱글톤 등) 수동

### After (Koin 사용)

```kotlin
val appModule = module {
    single { Database.connect(...) }
    single { UserService(get()) }
}

fun Application.configureDatabases() {
    val userService by inject<UserService>()  // 자동 주입
    routing { ... }
}
```

**장점:**
- 테스트 시 Mock 쉽게 주입
- 의존성 한 곳에서 관리
- 생명주기 자동 관리