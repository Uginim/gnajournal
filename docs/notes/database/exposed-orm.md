# Exposed ORM

## 개요

**Exposed**는 JetBrains에서 만든 Kotlin ORM 프레임워크이다. SQL DSL과 DAO 두 가지 방식을 지원한다.

## DSL vs DAO

| 방식 | 특징 | 사용 |
|-----|------|------|
| **DSL** | SQL과 유사한 코드 작성 | 현재 프로젝트에서 사용 |
| **DAO** | JPA처럼 Entity 객체 사용 | 더 객체지향적 |

> 상세 비교는 [Exposed DSL vs DAO 비교](./exposed-dsl-vs-dao.md) 참고

## 테이블 정의 (DSL 방식)

```kotlin
object Users : Table() {
    val id = integer("id").autoIncrement()
    val name = varchar("name", length = 50)
    val age = integer("age")

    override val primaryKey = PrimaryKey(id)
}
```

### 컬럼 타입

| Kotlin | SQL |
|--------|-----|
| `integer("col")` | INT |
| `varchar("col", 50)` | VARCHAR(50) |
| `text("col")` | TEXT |
| `bool("col")` | BOOLEAN |
| `datetime("col")` | TIMESTAMP |

### 컬럼 옵션

```kotlin
val id = integer("id").autoIncrement()        // 자동 증가
val email = varchar("email", 255).uniqueIndex() // 유니크 인덱스
val bio = text("bio").nullable()               // NULL 허용
val active = bool("active").default(true)      // 기본값
```

## 데이터베이스 연결

```kotlin
val database = Database.connect(
    url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1",
    user = "root",
    driver = "org.h2.Driver",
    password = "",
)
```

### URL 형식

| DB | URL |
|----|-----|
| H2 (메모리) | `jdbc:h2:mem:test` |
| H2 (파일) | `jdbc:h2:./data/test` |
| PostgreSQL | `jdbc:postgresql://localhost:5432/dbname` |
| MySQL | `jdbc:mysql://localhost:3306/dbname` |

## 테이블 생성

```kotlin
transaction(database) {
    SchemaUtils.create(Users)  // 테이블 생성
    SchemaUtils.createMissingTablesAndColumns(Users)  // 없는 것만 생성
}
```

## CRUD 작업

### Create (INSERT)

```kotlin
Users.insert {
    it[name] = "Kim"
    it[age] = 25
}

// ID 반환
val id = Users.insert {
    it[name] = "Kim"
    it[age] = 25
}[Users.id]
```

### Read (SELECT)

```kotlin
// 전체 조회
Users.selectAll().forEach { row ->
    println(row[Users.name])
}

// 조건 조회
Users.selectAll()
    .where { Users.id eq 1 }
    .singleOrNull()

// 특정 컬럼만
Users.select(Users.name, Users.age)
    .where { Users.age greater 20 }
```

### Update

```kotlin
Users.update({ Users.id eq 1 }) {
    it[name] = "Lee"
    it[age] = 30
}
```

### Delete

```kotlin
Users.deleteWhere { Users.id eq 1 }
```

## 트랜잭션

모든 DB 작업은 **트랜잭션** 안에서 실행해야 한다.

```kotlin
// 동기 트랜잭션
transaction {
    Users.insert { ... }
}

// 비동기 트랜잭션 (Ktor에서 권장)
suspend fun create(user: User): Int = dbQuery {
    Users.insert { ... }[Users.id]
}

private suspend fun <T> dbQuery(block: suspend () -> T): T =
    newSuspendedTransaction(Dispatchers.IO) { block() }
```

### 왜 newSuspendedTransaction을 쓰는가?

- Ktor는 **코루틴** 기반
- 일반 `transaction`은 스레드 블로킹
- `newSuspendedTransaction`은 IO 디스패처에서 논블로킹 실행

## 현재 프로젝트 코드 분석

### UsersSchema.kt

```kotlin
@Serializable
data class ExposedUser(val name: String, val age: Int)

class UserService(database: Database) {
    object Users : Table() {
        val id = integer("id").autoIncrement()
        val name = varchar("name", length = 50)
        val age = integer("age")
        override val primaryKey = PrimaryKey(id)
    }

    init {
        transaction(database) {
            SchemaUtils.create(Users)  // 앱 시작 시 테이블 생성
        }
    }

    suspend fun create(user: ExposedUser): Int = dbQuery {
        Users.insert {
            it[name] = user.name
            it[age] = user.age
        }[Users.id]
    }

    suspend fun read(id: Int): ExposedUser? = dbQuery {
        Users.selectAll()
            .where { Users.id eq id }
            .map { ExposedUser(it[Users.name], it[Users.age]) }
            .singleOrNull()
    }

    // update, delete도 비슷한 패턴
}
```

### 패턴 정리

1. **DTO**: `@Serializable data class`로 정의
2. **Table**: `object`로 테이블 스키마 정의
3. **Service**: DB 작업을 캡슐화
4. **dbQuery**: 비동기 트랜잭션 헬퍼

## 조건 연산자

```kotlin
Users.id eq 1           // =
Users.id neq 1          // !=
Users.age greater 20    // >
Users.age greaterEq 20  // >=
Users.age less 30       // <
Users.age lessEq 30     // <=
Users.name like "%kim%" // LIKE
Users.name.isNull()     // IS NULL
```

### 복합 조건

```kotlin
(Users.age greater 20) and (Users.name like "%kim%")
(Users.id eq 1) or (Users.id eq 2)
```

## H2 데이터베이스

현재 프로젝트는 **H2 인메모리 DB**를 사용한다.

```kotlin
url = "jdbc:h2:mem:test;DB_CLOSE_DELAY=-1"
```

- `mem:test`: 메모리에 "test"라는 DB 생성
- `DB_CLOSE_DELAY=-1`: 연결이 없어도 DB 유지

### 특징

- 설치 불필요 (라이브러리에 포함)
- 빠름 (메모리)
- 앱 종료 시 데이터 삭제됨
- **개발/테스트용**으로 적합

### 프로덕션에서는?

PostgreSQL 또는 MySQL로 교체:

```kotlin
Database.connect(
    url = "jdbc:postgresql://localhost:5432/blog",
    driver = "org.postgresql.Driver",
    user = "postgres",
    password = "password"
)
```