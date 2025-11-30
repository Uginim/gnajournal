# 코틀린스러운 코딩 (Idiomatic Kotlin)

## 개요

"코틀린스럽다"는 것은 Kotlin 언어의 특징과 철학을 활용해 **간결하고, 안전하고, 표현력 있는** 코드를 작성하는 것이다.

---

## 1. Null 안전성 활용

### Java 스타일 (안 좋음)
```kotlin
fun getUsername(user: User?): String {
    if (user != null) {
        if (user.name != null) {
            return user.name
        }
    }
    return "Unknown"
}
```

### Kotlin 스타일 (좋음)
```kotlin
fun getUsername(user: User?): String {
    return user?.name ?: "Unknown"
}
```

### 핵심 연산자
| 연산자 | 이름 | 설명 |
|--------|------|------|
| `?.` | Safe call | null이면 null 반환 |
| `?:` | Elvis | null이면 기본값 반환 |
| `!!` | Not-null assertion | null이면 예외 (가급적 피하기) |
| `?.let { }` | Safe call + let | null이 아닐 때만 실행 |

### 실전 예시
```kotlin
// null 체크 + 변환
val length = text?.length ?: 0

// null 아닐 때만 실행
user?.let {
    saveToDatabase(it)
    sendEmail(it.email)
}

// 여러 단계 safe call
val city = user?.address?.city ?: "Unknown"
```

---

## 2. 스코프 함수 활용

### let - null 체크 또는 변환
```kotlin
// null이 아닐 때 실행
user?.let {
    println("User: ${it.name}")
}

// 변환
val result = "hello".let { it.uppercase() }  // "HELLO"
```

### apply - 객체 설정 (this 반환)
```kotlin
// Java 스타일
val user = User()
user.name = "Kim"
user.email = "kim@test.com"
user.age = 25

// Kotlin 스타일
val user = User().apply {
    name = "Kim"
    email = "kim@test.com"
    age = 25
}
```

### also - 부수 효과 (원본 반환)
```kotlin
// 로깅하면서 체이닝
val user = createUser()
    .also { println("Created: $it") }
    .also { validate(it) }
```

### run - 객체에서 계산 후 결과 반환
```kotlin
val greeting = user.run {
    "Hello, $name! You are $age years old."
}
```

### with - run과 비슷, 비확장 함수 버전
```kotlin
val result = with(user) {
    "$name ($email)"
}
```

### 스코프 함수 선택 가이드
| 함수 | 반환값 | this/it | 용도 |
|------|--------|---------|------|
| `let` | 람다 결과 | it | null 체크, 변환 |
| `apply` | this | this | 객체 설정 |
| `also` | this | it | 부수 효과, 로깅 |
| `run` | 람다 결과 | this | 객체에서 계산 |
| `with` | 람다 결과 | this | 그룹 연산 |

---

## 3. 확장 함수

### 기존 클래스에 함수 추가
```kotlin
// String에 함수 추가
fun String.toSlug(): String {
    return this.lowercase()
        .replace(" ", "-")
        .replace(Regex("[^a-z0-9-]"), "")
}

// 사용
val slug = "Hello World!".toSlug()  // "hello-world"
```

### 실전 예시 - 프로젝트에서 유용한 확장 함수
```kotlin
// ResultRow를 DTO로 변환
fun ResultRow.toPostDto() = PostDto(
    id = this[Posts.id],
    title = this[Posts.title],
    summary = this[Posts.summary]
)

// 사용
Posts.selectAll().map { it.toPostDto() }
```

```kotlin
// LocalDateTime 포맷팅
fun LocalDateTime.toDisplayFormat(): String {
    return this.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))
}

// 사용
post.createdAt.toDisplayFormat()  // "2024-11-26 14:30"
```

---

## 4. 데이터 클래스

### Java 스타일 (안 좋음)
```kotlin
class User {
    var name: String = ""
    var email: String = ""

    override fun equals(other: Any?): Boolean { ... }
    override fun hashCode(): Int { ... }
    override fun toString(): String { ... }
}
```

### Kotlin 스타일 (좋음)
```kotlin
data class User(
    val name: String,
    val email: String
)
// equals, hashCode, toString, copy 자동 생성
```

### copy로 불변 객체 수정
```kotlin
val user1 = User("Kim", "kim@test.com")
val user2 = user1.copy(name = "Lee")  // email은 유지
```

### 구조 분해
```kotlin
val (name, email) = user
println("$name - $email")

// 리스트에서
users.forEach { (name, email) ->
    println("$name: $email")
}
```

---

## 5. 컬렉션 함수형 처리

### Java 스타일 (안 좋음)
```kotlin
val result = mutableListOf<String>()
for (user in users) {
    if (user.age >= 20) {
        result.add(user.name.uppercase())
    }
}
```

### Kotlin 스타일 (좋음)
```kotlin
val result = users
    .filter { it.age >= 20 }
    .map { it.name.uppercase() }
```

### 자주 쓰는 컬렉션 함수
```kotlin
// filter - 조건에 맞는 것만
users.filter { it.age >= 20 }

// map - 변환
users.map { it.name }

// find - 첫 번째 매칭 (nullable)
users.find { it.name == "Kim" }

// firstOrNull - find와 동일
users.firstOrNull { it.name == "Kim" }

// any - 하나라도 조건 만족?
users.any { it.age >= 20 }

// all - 모두 조건 만족?
users.all { it.age >= 20 }

// none - 모두 조건 불만족?
users.none { it.age < 0 }

// groupBy - 그룹화
users.groupBy { it.department }

// sortedBy - 정렬
users.sortedBy { it.age }
users.sortedByDescending { it.createdAt }

// take / drop
users.take(5)  // 처음 5개
users.drop(5)  // 처음 5개 제외

// distinct - 중복 제거
names.distinct()

// associate - Map으로 변환
users.associate { it.id to it.name }  // Map<Int, String>
```

### 체이닝 예시
```kotlin
// 20세 이상 사용자의 이름을 나이순으로 정렬해서 5명만
val result = users
    .filter { it.age >= 20 }
    .sortedBy { it.age }
    .take(5)
    .map { it.name }
```

---

## 6. when 표현식

### if-else 체인 대신 when
```kotlin
// Java 스타일
val message: String
if (score >= 90) {
    message = "A"
} else if (score >= 80) {
    message = "B"
} else {
    message = "C"
}

// Kotlin 스타일
val message = when {
    score >= 90 -> "A"
    score >= 80 -> "B"
    else -> "C"
}
```

### 값 매칭
```kotlin
val result = when (status) {
    Status.PENDING -> "대기 중"
    Status.APPROVED -> "승인됨"
    Status.REJECTED -> "거절됨"
}
```

### 타입 체크
```kotlin
fun process(value: Any) = when (value) {
    is String -> "문자열: ${value.length}자"
    is Int -> "숫자: $value"
    is List<*> -> "리스트: ${value.size}개"
    else -> "알 수 없음"
}
```

---

## 7. 기본값과 명명된 인자

### 오버로딩 대신 기본값
```kotlin
// Java 스타일 - 여러 생성자
class User(name: String) { ... }
class User(name: String, age: Int) { ... }
class User(name: String, age: Int, email: String) { ... }

// Kotlin 스타일 - 기본값
data class User(
    val name: String,
    val age: Int = 0,
    val email: String = ""
)
```

### 명명된 인자로 가독성 향상
```kotlin
// 뭐가 뭔지 모름
createUser("Kim", 25, true, false)

// 명확함
createUser(
    name = "Kim",
    age = 25,
    isAdmin = true,
    isActive = false
)
```

---

## 8. sealed class로 상태 표현

### 여러 상태를 타입으로 표현
```kotlin
sealed class Result<out T> {
    data class Success<T>(val data: T) : Result<T>()
    data class Error(val message: String) : Result<Nothing>()
    object Loading : Result<Nothing>()
}

// 사용
fun handleResult(result: Result<User>) = when (result) {
    is Result.Success -> println("User: ${result.data}")
    is Result.Error -> println("Error: ${result.message}")
    Result.Loading -> println("Loading...")
    // else 불필요 - 컴파일러가 모든 케이스 체크
}
```

---

## 9. 표현식 본문 함수

### 단일 표현식은 = 로
```kotlin
// 블록 본문
fun double(x: Int): Int {
    return x * 2
}

// 표현식 본문
fun double(x: Int) = x * 2

// 타입 추론
fun isAdult(age: Int) = age >= 20
```

---

## 10. 문자열 템플릿

### 변수 삽입
```kotlin
// Java 스타일
val message = "Hello, " + user.name + "! You are " + user.age + " years old."

// Kotlin 스타일
val message = "Hello, ${user.name}! You are ${user.age} years old."

// 단순 변수는 {} 생략 가능
val greeting = "Hello, $name"
```

### 여러 줄 문자열
```kotlin
val html = """
    <html>
        <body>
            <h1>$title</h1>
            <p>${content.take(100)}</p>
        </body>
    </html>
""".trimIndent()
```

---

## 실전: 블로그 프로젝트에 적용

### Before (Java 스타일)
```kotlin
fun getPublishedPosts(page: Int, size: Int): List<PostDto> {
    val posts = mutableListOf<PostDto>()
    val rows = Posts.selectAll()
        .where { Posts.published eq true }
        .orderBy(Posts.createdAt to SortOrder.DESC)
        .limit(size).offset(((page - 1) * size).toLong())

    for (row in rows) {
        val dto = PostDto(
            row[Posts.id],
            row[Posts.title],
            row[Posts.summary]
        )
        posts.add(dto)
    }
    return posts
}
```

### After (Kotlin 스타일)
```kotlin
fun getPublishedPosts(page: Int, size: Int) = Posts
    .selectAll()
    .where { Posts.published eq true }
    .orderBy(Posts.createdAt to SortOrder.DESC)
    .limit(size).offset(((page - 1) * size).toLong())
    .map { it.toPostDto() }

// 확장 함수
private fun ResultRow.toPostDto() = PostDto(
    id = this[Posts.id],
    title = this[Posts.title],
    summary = this[Posts.summary]
)
```

---

## 안티패턴 (피해야 할 것들)

### 1. !! 남용
```kotlin
// 나쁨 - NPE 위험
val name = user!!.name!!

// 좋음
val name = user?.name ?: "Unknown"
```

### 2. 불필요한 변수 타입 명시
```kotlin
// 불필요 - 타입 추론됨
val name: String = user.name
val count: Int = list.size

// 좋음
val name = user.name
val count = list.size
```

### 3. mutableList 남용
```kotlin
// 나쁨
val result = mutableListOf<String>()
for (user in users) {
    result.add(user.name)
}

// 좋음
val result = users.map { it.name }
```

### 4. 단일 표현식에 블록 사용
```kotlin
// 불필요하게 장황
fun isValid(age: Int): Boolean {
    return age >= 0
}

// 간결
fun isValid(age: Int) = age >= 0
```

---

## 참고

- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [Kotlin Idioms](https://kotlinlang.org/docs/idioms.html)