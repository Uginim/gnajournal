# Exposed DSL vs DAO 비교

## 개요

Exposed는 두 가지 방식을 제공한다:
- **DSL**: SQL과 유사한 코드 작성
- **DAO**: JPA처럼 Entity 객체 사용

---

## 같은 작업을 두 방식으로 비교

### 테이블 정의

**DSL 방식:**
```kotlin
// 테이블만 정의
object Users : Table("users") {
    val id = integer("id").autoIncrement()
    val name = varchar("name", 50)
    val email = varchar("email", 255)

    override val primaryKey = PrimaryKey(id)
}
```

**DAO 방식:**
```kotlin
// 테이블 + Entity 클래스 정의
object Users : IntIdTable("users") {
    val name = varchar("name", 50)
    val email = varchar("email", 255)
}

// Entity 클래스 (JPA의 @Entity와 유사)
class User(id: EntityID<Int>) : IntEntity(id) {
    companion object : IntEntityClass<User>(Users)

    var name by Users.name
    var email by Users.email
}
```

**차이점:**
- DSL: `Table()` 상속, id 직접 정의
- DAO: `IntIdTable()` 상속 (id 자동 포함), Entity 클래스 필요

---

### Create (생성)

**DSL 방식:**
```kotlin
// SQL INSERT와 유사
val userId = Users.insert {
    it[name] = "Kim"
    it[email] = "kim@example.com"
}[Users.id]

// 반환값: Int (ID)
```

**DAO 방식:**
```kotlin
// 객체 생성하듯이
val user = User.new {
    name = "Kim"
    email = "kim@example.com"
}

// 반환값: User 객체 (user.id, user.name 등 접근 가능)
```

**차이점:**
- DSL: `insert { it[column] = value }` 문법, ID만 반환
- DAO: `new { }` 문법, 전체 Entity 반환

---

### Read (조회)

**DSL 방식:**
```kotlin
// ResultRow를 직접 다룸
val row = Users.selectAll()
    .where { Users.id eq 1 }
    .singleOrNull()

// 컬럼 접근
val name = row?.get(Users.name)
val email = row?.get(Users.email)

// DTO로 변환 필요
val userDto = row?.let {
    UserDto(it[Users.id], it[Users.name], it[Users.email])
}
```

**DAO 방식:**
```kotlin
// Entity 객체로 바로 반환
val user = User.findById(1)

// 프로퍼티로 접근
val name = user?.name
val email = user?.email

// 이미 객체이므로 바로 사용 가능
```

**차이점:**
- DSL: `ResultRow` 반환 → 수동으로 DTO 변환
- DAO: Entity 객체 반환 → 바로 사용 가능

---

### Update (수정)

**DSL 방식:**
```kotlin
// SQL UPDATE와 유사
Users.update({ Users.id eq 1 }) {
    it[name] = "Lee"
    it[email] = "lee@example.com"
}
```

**DAO 방식:**
```kotlin
// 객체 프로퍼티 수정
val user = User.findById(1)
user?.apply {
    name = "Lee"
    email = "lee@example.com"
}
// 트랜잭션 종료 시 자동 저장 (Dirty Checking)
```

**차이점:**
- DSL: 명시적 UPDATE 쿼리
- DAO: 프로퍼티 변경 후 자동 저장 (JPA와 동일)

---

### Delete (삭제)

**DSL 방식:**
```kotlin
Users.deleteWhere { Users.id eq 1 }
```

**DAO 방식:**
```kotlin
val user = User.findById(1)
user?.delete()
```

---

### 관계 (1:N) 처리

**DSL 방식:**
```kotlin
// 테이블 정의
object Posts : Table("posts") {
    val id = integer("id").autoIncrement()
    val title = varchar("title", 200)
    val userId = reference("user_id", Users)  // FK
}

// 조회: JOIN 직접 작성
(Users innerJoin Posts)
    .selectAll()
    .where { Users.id eq 1 }
    .forEach { row ->
        println("${row[Users.name]} - ${row[Posts.title]}")
    }
```

**DAO 방식:**
```kotlin
// 테이블 정의
object Posts : IntIdTable("posts") {
    val title = varchar("title", 200)
    val user = reference("user_id", Users)
}

// Entity 정의
class Post(id: EntityID<Int>) : IntEntity(id) {
    companion object : IntEntityClass<Post>(Posts)

    var title by Posts.title
    var user by User referencedOn Posts.user  // 관계 정의
}

class User(id: EntityID<Int>) : IntEntity(id) {
    companion object : IntEntityClass<User>(Users)

    var name by Users.name
    val posts by Post referrersOn Posts.user  // 역방향 관계
}

// 조회: 객체 탐색으로 접근
val user = User.findById(1)
user?.posts?.forEach { post ->
    println("${user.name} - ${post.title}")
}
```

**차이점:**
- DSL: JOIN 쿼리 직접 작성
- DAO: `referencedOn`, `referrersOn`으로 관계 정의 후 객체 탐색

---

## 복잡한 쿼리 예시

### 집계 쿼리

**DSL 방식:**
```kotlin
// 사용자별 게시글 수
Users
    .join(Posts, JoinType.LEFT, Users.id, Posts.userId)
    .select(Users.name, Posts.id.count())
    .groupBy(Users.id)
    .forEach { row ->
        println("${row[Users.name]}: ${row[Posts.id.count()]}개")
    }
```

**DAO 방식:**
```kotlin
// 단순 카운트는 가능하지만...
User.all().forEach { user ->
    println("${user.name}: ${user.posts.count()}개")
}
// N+1 문제 발생 가능!
```

### 서브쿼리

**DSL 방식:**
```kotlin
// 게시글이 있는 사용자만 조회
val usersWithPosts = Users.selectAll()
    .where {
        Users.id inSubQuery Posts.select(Posts.userId).distinct()
    }
```

**DAO 방식:**
```kotlin
// 서브쿼리는 DSL 사용 권장
```

---

## 선택 가이드

| 상황 | 추천 방식 | 이유 |
|------|----------|------|
| 복잡한 쿼리, 집계 | **DSL** | SQL에 가까워 세밀한 제어 가능 |
| 단순 CRUD | **DAO** | 코드가 간결, 객체지향적 |
| 성능 최적화 필요 | **DSL** | 필요한 컬럼만 SELECT 가능 |
| 관계가 복잡한 도메인 | **DAO** | 객체 그래프 탐색이 편함 |
| SQL 익숙한 개발자 | **DSL** | 러닝커브 낮음 |
| JPA 익숙한 개발자 | **DAO** | 패턴이 비슷함 |
| 배치 작업 | **DSL** | 대량 INSERT/UPDATE 효율적 |

---

## 혼합 사용

두 방식을 함께 사용할 수 있다:

```kotlin
// DAO로 Entity 정의
class User(id: EntityID<Int>) : IntEntity(id) {
    companion object : IntEntityClass<User>(Users)
    var name by Users.name
}

// 단순 조회는 DAO
val user = User.findById(1)

// 복잡한 쿼리는 DSL
val stats = Users
    .join(Posts, JoinType.LEFT, Users.id, Posts.userId)
    .select(Users.name, Posts.id.count())
    .groupBy(Users.id)
```

---

## 의존성

```kotlin
// DSL만 사용
implementation("org.jetbrains.exposed:exposed-core:$exposed_version")
implementation("org.jetbrains.exposed:exposed-jdbc:$exposed_version")

// DAO도 사용
implementation("org.jetbrains.exposed:exposed-dao:$exposed_version")
```

---

---

## 실제 사례별 비교

### 사례 1: 페이지네이션이 있는 목록 조회

**DSL (권장):**
```kotlin
// 명확하고 SQL과 유사
fun findPublishedPosts(page: Int, size: Int): List<PostDto> {
    return Posts.selectAll()
        .where { Posts.published eq true }
        .orderBy(Posts.createdAt to SortOrder.DESC)
        .limit(size).offset(((page - 1) * size).toLong())
        .map { row ->
            PostDto(
                id = row[Posts.id],
                title = row[Posts.title],
                summary = row[Posts.summary]
            )
        }
}
```

**DAO:**
```kotlin
// 가능하지만 덜 직관적
fun findPublishedPosts(page: Int, size: Int): List<Post> {
    return Post.find { Posts.published eq true }
        .orderBy(Posts.createdAt to SortOrder.DESC)
        .limit(size, offset = ((page - 1) * size).toLong())
        .toList()
}
```

**승자: DSL** - 페이지네이션, 정렬이 SQL처럼 명확함

---

### 사례 2: 집계 쿼리 (태그별 글 수)

**DSL (권장):**
```kotlin
// SQL 집계 함수 직접 사용
fun getTagStats(): List<TagStatDto> {
    return Tags
        .join(PostTags, JoinType.LEFT, Tags.id, PostTags.tag)
        .select(Tags.id, Tags.name, PostTags.post.count())
        .groupBy(Tags.id)
        .map { row ->
            TagStatDto(
                name = row[Tags.name],
                postCount = row[PostTags.post.count()]
            )
        }
}
```

**DAO:**
```kotlin
// N+1 문제 발생!
fun getTagStats(): List<TagStatDto> {
    return Tag.all().map { tag ->
        TagStatDto(
            name = tag.name,
            postCount = tag.posts.count()  // 태그마다 쿼리 발생
        )
    }
}
```

**승자: DSL** - 집계는 DSL이 압도적, DAO는 N+1 문제

---

### 사례 3: 검색 기능

**DSL (권장):**
```kotlin
// 복잡한 OR 조건도 깔끔
fun search(keyword: String): List<PostDto> {
    val pattern = "%$keyword%"
    return Posts.selectAll()
        .where {
            (Posts.title like pattern) or
            (Posts.content like pattern) or
            (Posts.summary like pattern)
        }
        .orderBy(Posts.createdAt to SortOrder.DESC)
        .map { it.toDto() }
}
```

**DAO:**
```kotlin
// 동일하게 가능
fun search(keyword: String): List<Post> {
    val pattern = "%$keyword%"
    return Post.find {
        (Posts.title like pattern) or
        (Posts.content like pattern)
    }.toList()
}
```

**승자: 비슷** - 둘 다 괜찮음, DSL이 약간 더 명확

---

### 사례 4: 단일 엔티티 CRUD

**DSL:**
```kotlin
// 생성
val id = Posts.insert {
    it[title] = "제목"
    it[content] = "내용"
    it[authorId] = userId
}[Posts.id]

// 조회
val post = Posts.selectAll()
    .where { Posts.id eq id }
    .singleOrNull()
    ?.let { PostDto(it[Posts.id], it[Posts.title], ...) }

// 수정
Posts.update({ Posts.id eq id }) {
    it[title] = "새 제목"
}

// 삭제
Posts.deleteWhere { Posts.id eq id }
```

**DAO (권장):**
```kotlin
// 생성 - 객체처럼 자연스러움
val post = Post.new {
    title = "제목"
    content = "내용"
    author = user
}

// 조회
val post = Post.findById(id)

// 수정 - 프로퍼티만 바꾸면 자동 저장
post?.apply {
    title = "새 제목"
}

// 삭제
post?.delete()
```

**승자: DAO** - 단순 CRUD는 DAO가 더 간결하고 직관적

---

### 사례 5: 관계 데이터 함께 조회 (글 + 작성자)

**DSL:**
```kotlin
// JOIN 직접 작성
fun getPostWithAuthor(postId: Int): PostDetailDto? {
    return (Posts innerJoin Users)
        .selectAll()
        .where { Posts.id eq postId }
        .singleOrNull()
        ?.let { row ->
            PostDetailDto(
                id = row[Posts.id],
                title = row[Posts.title],
                content = row[Posts.content],
                author = AuthorDto(
                    id = row[Users.id],
                    name = row[Users.name]
                )
            )
        }
}
```

**DAO (권장):**
```kotlin
// 객체 탐색으로 자연스럽게
fun getPostWithAuthor(postId: Int): Post? {
    return Post.findById(postId)
    // post.author.name 으로 바로 접근
}

// Entity 정의
class Post(id: EntityID<Int>) : IntEntity(id) {
    var title by Posts.title
    var author by User referencedOn Posts.authorId  // 관계 자동 로딩
}
```

**승자: DAO** - 관계 탐색은 DAO가 편함 (단, Eager/Lazy 로딩 주의)

---

### 사례 6: 대량 데이터 처리

**DSL (권장):**
```kotlin
// 배치 INSERT
Posts.batchInsert(postList) { post ->
    this[Posts.title] = post.title
    this[Posts.content] = post.content
}

// 조건부 대량 UPDATE
Posts.update({ Posts.published eq false }) {
    it[published] = true
    it[publishedAt] = LocalDateTime.now()
}

// 대량 DELETE
Posts.deleteWhere { Posts.createdAt less someDate }
```

**DAO:**
```kotlin
// 비효율적 - 각각 쿼리 발생
postList.forEach { postData ->
    Post.new {
        title = postData.title
        content = postData.content
    }
}
```

**승자: DSL** - 배치 작업은 DSL이 훨씬 효율적

---

### 사례 7: 복잡한 서브쿼리

**DSL (권장):**
```kotlin
// 댓글이 가장 많은 글 TOP 10
val subquery = Comments
    .select(Comments.postId, Comments.id.count())
    .groupBy(Comments.postId)
    .alias("comment_counts")

Posts.join(subquery, JoinType.LEFT, Posts.id, subquery[Comments.postId])
    .selectAll()
    .orderBy(subquery[Comments.id.count()] to SortOrder.DESC)
    .limit(10)
```

**DAO:**
```kotlin
// 서브쿼리는 DSL로 해야 함
// DAO만으로는 불가능
```

**승자: DSL** - 복잡한 쿼리는 DSL만 가능

---

## 블로그 프로젝트 권장 방식

### 결론: DSL 사용 (현재 프로젝트)

| 기능 | 권장 방식 | 이유 |
|------|----------|------|
| 글 목록 (페이지네이션) | DSL | 정렬, 페이징 명확 |
| 글 검색 | DSL | OR 조건 처리 |
| 태그별 글 수 | DSL | 집계 쿼리 |
| 인기글 TOP N | DSL | 정렬 + LIMIT |
| 글 상세 조회 | DSL | JOIN으로 작성자 포함 |
| 글 작성/수정/삭제 | DSL | 일관성 유지 |

### 이유

1. **일관성**: 전체 코드베이스가 DSL로 통일
2. **블로그 특성**: 목록, 검색, 집계가 많음 → DSL 강점
3. **학습 곡선**: SQL 알면 바로 적용 가능
4. **성능**: 필요한 컬럼만 SELECT 가능

### DAO 고려 시점

- 댓글 대댓글 (재귀 관계)
- 복잡한 도메인 로직이 Entity에 필요할 때
- 팀에 JPA 경험자가 많을 때

---

## 참고

- [Exposed Wiki - DSL](https://github.com/JetBrains/Exposed/wiki/DSL)
- [Exposed Wiki - DAO](https://github.com/JetBrains/Exposed/wiki/DAO)