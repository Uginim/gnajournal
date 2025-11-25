# Ktor 블로그 구현 로드맵

Kotlin + Ktor 블로그 프로젝트의 단계별 구현 가이드입니다.

---

## 전체 일정 개요

```
Phase 1: 프로젝트 셋업          ████░░░░░░░░░░░░░░░░  1주
Phase 2: 데이터베이스 & 모델     ████░░░░░░░░░░░░░░░░  1주
Phase 3: 기본 페이지 구현        ████████░░░░░░░░░░░░  2주
Phase 4: 인증 시스템            ████░░░░░░░░░░░░░░░░  1주
Phase 5: 어드민 & 에디터        ████████░░░░░░░░░░░░  2주
Phase 6: 검색 & SEO            ████░░░░░░░░░░░░░░░░  1주
Phase 7: 테스트 & 최적화        ████░░░░░░░░░░░░░░░░  1주
Phase 8: 배포                  ██░░░░░░░░░░░░░░░░░░  3일
─────────────────────────────────────────────────────
총 예상 기간: 8-10주
```

---

## Phase 1: 프로젝트 셋업 (1주)

### 목표
- Ktor 프로젝트 생성 및 기본 구조 설정
- 개발 환경 구축

### 체크리스트

#### 1.1 프로젝트 생성
- [ ] [start.ktor.io](https://start.ktor.io) 에서 프로젝트 생성
  - Project: Gradle (Kotlin DSL)
  - Ktor version: 2.3.x
  - Engine: Netty
- [ ] IntelliJ IDEA에서 프로젝트 열기
- [ ] Gradle sync 확인

#### 1.2 의존성 추가
- [ ] build.gradle.kts에 모든 의존성 추가
- [ ] 버전 카탈로그 설정 (선택)

#### 1.3 기본 구조 생성
```
src/main/kotlin/com/ulog/
├── Application.kt
├── plugins/
├── routes/
├── templates/
├── models/
├── repositories/
├── services/
└── utils/
```

#### 1.4 설정 파일
- [ ] application.conf 작성
- [ ] logback.xml 작성
- [ ] .gitignore 설정
- [ ] .env.example 작성

#### 1.5 플러그인 설정
- [ ] configureRouting()
- [ ] configureSerialization()
- [ ] configureSecurity() (기본)
- [ ] configureCompression()

#### 1.6 Hello World 확인
```kotlin
// Application.kt
fun main(args: Array<String>) {
    embeddedServer(Netty, port = 8080) {
        routing {
            get("/") {
                call.respondText("Hello, Ktor!")
            }
        }
    }.start(wait = true)
}
```
- [ ] 서버 실행 및 확인

### 산출물
- 실행 가능한 Ktor 프로젝트
- 기본 디렉토리 구조
- 설정 파일들

---

## Phase 2: 데이터베이스 & 모델 (1주)

### 목표
- PostgreSQL 연결
- Exposed ORM 설정
- 데이터 모델 정의
- **Koin DI 도입**

### 체크리스트

#### 2.0 Koin DI 설정
- [ ] Koin 의존성 추가
```kotlin
// build.gradle.kts
val koin_version = "3.5.0"
dependencies {
    implementation("io.insert-koin:koin-ktor:$koin_version")
    implementation("io.insert-koin:koin-logger-slf4j:$koin_version")
}
```
- [ ] AppModule 정의 (`di/AppModule.kt`)
- [ ] Application에 Koin 설치
```kotlin
install(Koin) {
    slf4jLogger()
    modules(appModule)
}
```

#### 2.1 로컬 DB 설정
- [ ] Docker Compose로 PostgreSQL 실행
```yaml
# docker-compose.dev.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ulog
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: devpassword
    ports:
      - "5432:5432"
```

#### 2.2 DB 연결 설정
- [ ] HikariCP 설정
- [ ] Exposed 연결
```kotlin
// plugins/Database.kt
fun Application.configureDatabase() {
    val config = HikariConfig().apply {
        jdbcUrl = "jdbc:postgresql://localhost:5432/ulog"
        username = "postgres"
        password = "devpassword"
        driverClassName = "org.postgresql.Driver"
        maximumPoolSize = 10
    }
    Database.connect(HikariDataSource(config))
}
```

#### 2.3 모델 정의

##### Users 테이블
```kotlin
object Users : IntIdTable("users") {
    val email = varchar("email", 255).uniqueIndex()
    val username = varchar("username", 50).uniqueIndex()
    val password = varchar("password", 255)
    val adminPermission = bool("admin_permission").default(false)
    val createdAt = datetime("created_at")
    val updatedAt = datetime("updated_at")
}
```

##### Posts 테이블
```kotlin
object Posts : IntIdTable("posts") {
    val title = varchar("title", 200)
    val slug = varchar("slug", 250).uniqueIndex()
    val content = text("content")
    val contentHtml = text("content_html")  // 렌더링된 HTML
    val summary = varchar("summary", 500).nullable()
    val thumbnail = varchar("thumbnail", 500).nullable()
    val published = bool("published").default(false)
    val categoryId = reference("category_id", Categories).nullable()
    val authorId = reference("author_id", Users)
    val viewCount = integer("view_count").default(0)
    val createdAt = datetime("created_at")
    val updatedAt = datetime("updated_at")
    val publishedAt = datetime("published_at").nullable()
}
```

##### Tags 테이블
```kotlin
object Tags : IntIdTable("tags") {
    val title = varchar("title", 50).uniqueIndex()
    val slug = varchar("slug", 60).uniqueIndex()
}

object PostTags : Table("post_tags") {
    val post = reference("post_id", Posts)
    val tag = reference("tag_id", Tags)
    override val primaryKey = PrimaryKey(post, tag)
}
```

##### Categories 테이블
```kotlin
object Categories : IntIdTable("categories") {
    val name = varchar("name", 50)
    val slug = varchar("slug", 60).uniqueIndex()
    val description = varchar("description", 200).nullable()
}
```

##### Comments 테이블 (선택)
```kotlin
object Comments : IntIdTable("comments") {
    val postId = reference("post_id", Posts)
    val authorName = varchar("author_name", 50)
    val content = text("content")
    val createdAt = datetime("created_at")
}
```

#### 2.4 DAO 클래스 정의
- [ ] User 엔티티
- [ ] Post 엔티티
- [ ] Tag 엔티티
- [ ] Category 엔티티

#### 2.5 DTO 정의
```kotlin
@Serializable
data class PostDTO(
    val id: Int,
    val title: String,
    val slug: String,
    val summary: String?,
    val thumbnail: String?,
    val tags: List<TagDTO>,
    val category: CategoryDTO?,
    val createdAt: String,
    val viewCount: Int
)
```

#### 2.6 Repository 기본 구현
- [ ] UserRepository (findByEmail, create)
- [ ] PostRepository (findAll, findById, create, update, delete)
- [ ] TagRepository (findAll, findOrCreate)
- [ ] CategoryRepository (findAll, findById)

#### 2.7 테이블 자동 생성
```kotlin
transaction {
    SchemaUtils.createMissingTablesAndColumns(
        Users, Posts, Tags, PostTags, Categories, Comments
    )
}
```

### 산출물
- DB 연결 완료
- 모든 테이블 생성
- 기본 Repository 구현

---

## Phase 3: 기본 페이지 구현 (2주)

### 목표
- HTML DSL로 레이아웃 및 페이지 구현
- Tailwind CSS 스타일링
- 기본 라우트 설정

### 체크리스트

#### 3.1 공통 레이아웃
```kotlin
// templates/Layout.kt
fun HTML.layout(
    title: String,
    description: String = "",
    user: UserSession? = null,
    content: MAIN.() -> Unit
) {
    head {
        meta { charset = "UTF-8" }
        meta { name = "viewport"; this.content = "width=device-width, initial-scale=1.0" }
        meta { name = "description"; this.content = description }
        title { +"$title | My Blog" }
        script { src = "https://cdn.tailwindcss.com" }
        script { src = "https://unpkg.com/htmx.org@1.9.10" }
        // Prism.js for code highlighting
        link { rel = "stylesheet"; href = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css" }
    }
    body(classes = "bg-gray-50 min-h-screen flex flex-col") {
        // Navigation
        nav(/* ... */)

        // Main content
        main(classes = "flex-grow max-w-6xl mx-auto px-4 py-8 w-full") {
            content()
        }

        // Footer
        footer(/* ... */)

        // Scripts
        script { src = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js" }
    }
}
```

#### 3.2 컴포넌트 구현
- [ ] Nav.kt - 네비게이션 바
- [ ] Footer.kt - 푸터
- [ ] PostCard.kt - 글 카드
- [ ] Pagination.kt - 페이지네이션
- [ ] TagCloud.kt - 태그 클라우드
- [ ] SearchBar.kt - 검색 바
- [ ] Seo.kt - SEO 메타 태그

#### 3.3 홈 페이지
```kotlin
// routes/HomeRoutes.kt
get("/") {
    val recentPosts = postRepository.findRecent(6)
    val popularTags = tagRepository.findPopular(10)

    call.respondHtml {
        layout("홈", "개발 블로그입니다") {
            // Hero section
            section(classes = "text-center py-12") {
                h1(classes = "text-4xl font-bold") { +"Welcome to My Blog" }
                p(classes = "text-gray-600 mt-4") { +"개발 이야기를 공유합니다" }
            }

            // Recent posts
            section {
                h2(classes = "text-2xl font-bold mb-6") { +"최신 글" }
                div(classes = "grid md:grid-cols-2 lg:grid-cols-3 gap-6") {
                    recentPosts.forEach { postCard(it) }
                }
            }
        }
    }
}
```

#### 3.4 글 목록 페이지
- [ ] GET /post - 전체 글 목록
- [ ] 페이지네이션 구현
- [ ] 정렬 옵션 (최신순, 인기순)

#### 3.5 글 상세 페이지
- [ ] GET /post/{id}
- [ ] GET /post/{id}/{slug} (SEO 친화적)
- [ ] 마크다운 → HTML 렌더링
- [ ] 코드 하이라이팅
- [ ] 목차(TOC) 생성
- [ ] 조회수 증가
- [ ] 관련 글 표시

#### 3.6 태그 페이지
- [ ] GET /tag/{name} - 태그별 글 목록

#### 3.7 마크다운 서비스
```kotlin
// services/MarkdownService.kt
class MarkdownService {
    private val parser = Parser.builder()
        .extensions(listOf(
            TablesExtension.create(),
            AutolinkExtension.create(),
            StrikethroughExtension.create(),
            HeadingAnchorExtension.create()
        ))
        .build()

    private val renderer = HtmlRenderer.builder()
        .extensions(/* ... */)
        .build()

    fun render(markdown: String): String {
        val document = parser.parse(markdown)
        return renderer.render(document)
    }

    fun extractToc(markdown: String): List<TocItem> {
        // 목차 추출 로직
    }
}
```

### 산출물
- 홈 페이지
- 글 목록 페이지 (페이지네이션)
- 글 상세 페이지 (마크다운 렌더링)
- 태그 페이지
- 반응형 디자인

---

## Phase 4: 인증 시스템 (1주)

### 목표
- 세션 기반 인증 구현
- 로그인/회원가입 페이지

### 체크리스트

#### 4.1 세션 설정
```kotlin
// plugins/Security.kt
@Serializable
data class UserSession(
    val id: Int,
    val email: String,
    val username: String,
    val adminPermission: Boolean
) : Principal

fun Application.configureSecurity() {
    install(Sessions) {
        cookie<UserSession>("user_session") {
            cookie.path = "/"
            cookie.maxAgeInSeconds = 60 * 60 * 24 * 7  // 7일
            cookie.httpOnly = true
            transform(SessionTransportTransformerMessageAuthentication(
                hex(environment.config.property("session.secret").getString())
            ))
        }
    }

    install(Authentication) {
        session<UserSession>("auth-session") {
            validate { session -> session }
            challenge { call.respondRedirect("/signin") }
        }
    }
}
```

#### 4.2 비밀번호 유틸
```kotlin
// utils/PasswordUtil.kt
object PasswordUtil {
    fun hash(password: String): String =
        BCrypt.hashpw(password, BCrypt.gensalt())

    fun verify(password: String, hashed: String): Boolean =
        BCrypt.checkpw(password, hashed)
}
```

#### 4.3 AuthService
```kotlin
// services/AuthService.kt
class AuthService(private val userRepository: UserRepository) {

    fun signIn(email: String, password: String): User? {
        val user = userRepository.findByEmail(email) ?: return null
        if (!PasswordUtil.verify(password, user.password)) return null
        return user
    }

    fun signUp(email: String, username: String, password: String): User {
        val hashedPassword = PasswordUtil.hash(password)
        return userRepository.create(email, username, hashedPassword)
    }
}
```

#### 4.4 인증 라우트
- [ ] GET /signin - 로그인 페이지
- [ ] POST /signin - 로그인 처리
- [ ] GET /signup - 회원가입 페이지
- [ ] POST /signup - 회원가입 처리
- [ ] POST /signout - 로그아웃

#### 4.5 입력 검증
```kotlin
// Konform 사용
val validateSignUp = Validation<SignUpRequest> {
    SignUpRequest::email {
        pattern("^[A-Za-z0-9+_.-]+@(.+)$") hint "유효한 이메일을 입력하세요"
    }
    SignUpRequest::username {
        minLength(2) hint "2자 이상 입력하세요"
        maxLength(50)
    }
    SignUpRequest::password {
        minLength(8) hint "8자 이상 입력하세요"
    }
}
```

#### 4.6 보호된 라우트 설정
```kotlin
authenticate("auth-session") {
    get("/admin") {
        val user = call.principal<UserSession>()!!
        // 어드민 페이지
    }
}
```

### 산출물
- 로그인/회원가입 페이지
- 세션 기반 인증
- 어드민 접근 제어

---

## Phase 5: 어드민 & 에디터 (2주)

### 목표
- 어드민 대시보드 구현
- Toast UI Editor 통합
- 글 CRUD 완성

### 체크리스트

#### 5.1 어드민 레이아웃
```kotlin
// templates/admin/AdminLayout.kt
fun HTML.adminLayout(
    title: String,
    user: UserSession,
    content: DIV.() -> Unit
) {
    layout(title, user = user) {
        div(classes = "flex gap-8") {
            // Sidebar
            aside(classes = "w-64 bg-white rounded-lg shadow p-4") {
                nav {
                    a(href = "/admin", classes = "block py-2") { +"대시보드" }
                    a(href = "/admin/posts", classes = "block py-2") { +"글 관리" }
                    a(href = "/admin/categories", classes = "block py-2") { +"카테고리" }
                    a(href = "/admin/settings", classes = "block py-2") { +"설정" }
                }
            }
            // Content
            div(classes = "flex-grow") {
                content()
            }
        }
    }
}
```

#### 5.2 대시보드
- [ ] GET /admin - 대시보드
- [ ] 통계 표시 (글 수, 조회수, 댓글 수)
- [ ] 최근 글 목록
- [ ] 최근 댓글 (선택)

#### 5.3 글 관리
- [ ] GET /admin/posts - 글 목록 (테이블)
- [ ] 공개/비공개 상태 표시
- [ ] 수정/삭제 버튼

#### 5.4 글 에디터 페이지
```kotlin
// templates/admin/PostEditorPage.kt
fun HTML.postEditorPage(user: UserSession, post: Post? = null) {
    adminLayout("글 작성", user) {
        form(
            action = "/admin/write",
            method = FormMethod.post,
            classes = "space-y-6"
        ) {
            // Hidden ID for edit
            post?.let {
                hiddenInput { name = "id"; value = it.id.value.toString() }
            }

            // Title
            div {
                label { +"제목" }
                textInput(classes = "w-full border rounded px-4 py-2") {
                    name = "title"
                    value = post?.title ?: ""
                }
            }

            // Category
            div {
                label { +"카테고리" }
                select(classes = "w-full border rounded px-4 py-2") {
                    name = "category"
                    // options...
                }
            }

            // Tags
            div {
                label { +"태그 (쉼표로 구분)" }
                textInput(classes = "w-full border rounded px-4 py-2") {
                    name = "tags"
                    placeholder = "kotlin, ktor, backend"
                }
            }

            // Editor container
            div {
                id = "editor"
            }
            hiddenInput {
                id = "content"
                name = "content"
            }

            // Submit
            button(type = ButtonType.submit, classes = "bg-blue-600 text-white px-6 py-2 rounded") {
                +"저장"
            }
        }

        // Toast UI Editor script
        script {
            unsafe {
                +"""
                const editor = new toastui.Editor({
                    el: document.querySelector('#editor'),
                    height: '500px',
                    initialEditType: 'markdown',
                    previewStyle: 'vertical',
                    initialValue: `${post?.content?.replace("`", "\\`") ?: ""}`
                });

                document.querySelector('form').addEventListener('submit', function() {
                    document.querySelector('#content').value = editor.getMarkdown();
                });
                """
            }
        }
    }
}
```

#### 5.5 글 저장 처리
```kotlin
// routes/AdminRoutes.kt
post("/admin/write") {
    val user = call.principal<UserSession>()!!
    val params = call.receiveParameters()

    val id = params["id"]?.toIntOrNull()
    val title = params["title"] ?: throw BadRequestException("제목 필수")
    val content = params["content"] ?: throw BadRequestException("내용 필수")
    val categoryId = params["category"]?.toIntOrNull()
    val tags = params["tags"]?.split(",")?.map { it.trim() } ?: emptyList()

    val contentHtml = markdownService.render(content)
    val slug = slugify(title)
    val summary = extractSummary(content, 200)

    if (id != null) {
        postRepository.update(id, title, slug, content, contentHtml, summary, categoryId, tags)
    } else {
        postRepository.create(title, slug, content, contentHtml, summary, categoryId, user.id, tags)
    }

    call.respondRedirect("/admin/posts")
}
```

#### 5.6 이미지 업로드 (선택)
- [ ] POST /admin/upload - 이미지 업로드
- [ ] Cloudinary 연동 또는 로컬 저장

#### 5.7 카테고리 관리
- [ ] GET /admin/categories
- [ ] POST /admin/categories - 추가
- [ ] DELETE /admin/categories/{id} - 삭제

#### 5.8 설정 페이지 (선택)
- [ ] 블로그 제목 설정
- [ ] 프로필 설정

### 산출물
- 어드민 대시보드
- Toast UI Editor 통합
- 글 CRUD 완성
- 카테고리 관리

---

## Phase 6: 검색 & SEO (1주)

### 목표
- 검색 기능 구현
- SEO 최적화

### 체크리스트

#### 6.1 검색 기능

##### 간단한 검색 (DB LIKE)
```kotlin
// repositories/PostRepository.kt
fun search(query: String, page: Int = 1, size: Int = 10): List<Post> = transaction {
    Post.find {
        (Posts.title like "%$query%") or (Posts.content like "%$query%")
    }
    .orderBy(Posts.createdAt to SortOrder.DESC)
    .limit(size, offset = ((page - 1) * size).toLong())
    .toList()
}
```

##### HTMX 검색 (실시간)
```kotlin
// routes/SearchRoutes.kt
get("/search") {
    val query = call.request.queryParameters["q"] ?: ""
    val posts = if (query.isNotBlank()) {
        postRepository.search(query)
    } else {
        emptyList()
    }

    call.respondHtml {
        layout("검색: $query") {
            // Search form with HTMX
            form(classes = "mb-8") {
                attributes["hx-get"] = "/search/results"
                attributes["hx-trigger"] = "keyup changed delay:300ms"
                attributes["hx-target"] = "#results"

                textInput(classes = "w-full border rounded px-4 py-3") {
                    name = "q"
                    placeholder = "검색어를 입력하세요..."
                    value = query
                }
            }

            div {
                id = "results"
                // Search results
                posts.forEach { postCard(it.toDTO()) }
            }
        }
    }
}

// HTMX partial
get("/search/results") {
    val query = call.request.queryParameters["q"] ?: ""
    val posts = postRepository.search(query)

    call.respondHtml {
        body {
            if (posts.isEmpty()) {
                p(classes = "text-gray-500") { +"검색 결과가 없습니다." }
            } else {
                posts.forEach { postCard(it.toDTO()) }
            }
        }
    }
}
```

#### 6.2 SEO 메타 태그
```kotlin
// templates/components/Seo.kt
fun HEAD.seoMeta(
    title: String,
    description: String,
    url: String,
    image: String? = null,
    type: String = "website"
) {
    // Basic
    meta { name = "description"; content = description }

    // Open Graph
    meta { attributes["property"] = "og:title"; content = title }
    meta { attributes["property"] = "og:description"; content = description }
    meta { attributes["property"] = "og:url"; content = url }
    meta { attributes["property"] = "og:type"; content = type }
    image?.let {
        meta { attributes["property"] = "og:image"; content = it }
    }

    // Twitter
    meta { name = "twitter:card"; content = "summary_large_image" }
    meta { name = "twitter:title"; content = title }
    meta { name = "twitter:description"; content = description }
}
```

#### 6.3 Sitemap
```kotlin
// routes/SeoRoutes.kt
get("/sitemap.xml") {
    val posts = postRepository.findAllPublished()
    val baseUrl = "https://yourblog.com"

    val sitemap = buildString {
        appendLine("""<?xml version="1.0" encoding="UTF-8"?>""")
        appendLine("""<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">""")

        // Home
        appendLine("""  <url><loc>$baseUrl/</loc><priority>1.0</priority></url>""")

        // Posts
        posts.forEach { post ->
            appendLine("""  <url>""")
            appendLine("""    <loc>$baseUrl/post/${post.id}/${post.slug}</loc>""")
            appendLine("""    <lastmod>${post.updatedAt.toLocalDate()}</lastmod>""")
            appendLine("""  </url>""")
        }

        appendLine("""</urlset>""")
    }

    call.respondText(sitemap, ContentType.Application.Xml)
}
```

#### 6.4 RSS 피드
```kotlin
get("/rss") {
    val posts = postRepository.findRecent(20)
    val baseUrl = "https://yourblog.com"

    val rss = buildString {
        appendLine("""<?xml version="1.0" encoding="UTF-8"?>""")
        appendLine("""<rss version="2.0">""")
        appendLine("""<channel>""")
        appendLine("""  <title>My Blog</title>""")
        appendLine("""  <link>$baseUrl</link>""")
        appendLine("""  <description>개발 블로그</description>""")

        posts.forEach { post ->
            appendLine("""  <item>""")
            appendLine("""    <title>${post.title.escapeXml()}</title>""")
            appendLine("""    <link>$baseUrl/post/${post.id}/${post.slug}</link>""")
            appendLine("""    <description>${post.summary?.escapeXml() ?: ""}</description>""")
            appendLine("""    <pubDate>${post.publishedAt?.toRssDate()}</pubDate>""")
            appendLine("""  </item>""")
        }

        appendLine("""</channel>""")
        appendLine("""</rss>""")
    }

    call.respondText(rss, ContentType.Application.Rss)
}
```

#### 6.5 robots.txt
```kotlin
get("/robots.txt") {
    call.respondText("""
        User-agent: *
        Allow: /

        Sitemap: https://yourblog.com/sitemap.xml
    """.trimIndent(), ContentType.Text.Plain)
}
```

#### 6.6 Canonical URL
- [ ] 글 상세 페이지에 canonical 태그 추가
- [ ] 중복 URL 방지

### 산출물
- 검색 기능 (HTMX 실시간)
- SEO 메타 태그
- sitemap.xml
- RSS 피드
- robots.txt

---

## Phase 7: 테스트 & 최적화 (1주)

### 목표
- 테스트 코드 작성
- 성능 최적화
- 캐싱 적용

### 체크리스트

#### 7.1 단위 테스트 (Kotest)
```kotlin
// test/repositories/PostRepositoryTest.kt
class PostRepositoryTest : StringSpec({
    val repository = PostRepository()

    beforeTest {
        Database.connect("jdbc:h2:mem:test;DB_CLOSE_DELAY=-1")
        transaction { SchemaUtils.create(Posts, Tags, PostTags) }
    }

    afterTest {
        transaction { SchemaUtils.drop(Posts, Tags, PostTags) }
    }

    "글 생성 테스트" {
        val post = repository.create(
            title = "테스트 글",
            slug = "test-post",
            content = "내용",
            contentHtml = "<p>내용</p>",
            summary = "요약",
            categoryId = null,
            authorId = 1,
            tags = listOf("kotlin", "ktor")
        )

        post.title shouldBe "테스트 글"
        post.tags.count() shouldBe 2
    }

    "검색 테스트" {
        // ...
    }
})
```

#### 7.2 통합 테스트
```kotlin
// test/routes/PostRoutesTest.kt
class PostRoutesTest : StringSpec({
    "GET /post 테스트" {
        testApplication {
            application { module() }

            val response = client.get("/post")

            response.status shouldBe HttpStatusCode.OK
        }
    }
})
```

#### 7.3 캐싱 적용
```kotlin
// services/CacheService.kt
class CacheService {
    private val cache: Cache<String, Any> = Caffeine.newBuilder()
        .maximumSize(1000)
        .expireAfterWrite(Duration.ofMinutes(10))
        .build()

    fun <T> get(key: String, loader: () -> T): T {
        @Suppress("UNCHECKED_CAST")
        return cache.get(key) { loader() } as T
    }

    fun invalidate(key: String) = cache.invalidate(key)
    fun invalidateAll() = cache.invalidateAll()
}

// 사용
val posts = cacheService.get("posts:recent:$page") {
    postRepository.findRecent(page)
}
```

#### 7.4 HTTP 캐싱
```kotlin
// plugins/Caching.kt
install(CachingHeaders) {
    options { call, content ->
        when (content.contentType?.withoutParameters()) {
            ContentType.Text.CSS -> CachingOptions(CacheControl.MaxAge(maxAgeSeconds = 86400))
            ContentType.Application.JavaScript -> CachingOptions(CacheControl.MaxAge(maxAgeSeconds = 86400))
            ContentType.Image.Any -> CachingOptions(CacheControl.MaxAge(maxAgeSeconds = 604800))
            else -> null
        }
    }
}
```

#### 7.5 압축
```kotlin
install(Compression) {
    gzip {
        priority = 1.0
        minimumSize(1024)
    }
    deflate {
        priority = 0.9
    }
}
```

#### 7.6 성능 테스트
- [ ] 응답 시간 측정
- [ ] 메모리 사용량 확인
- [ ] 부하 테스트 (선택)

### 산출물
- 테스트 코드 (80% 커버리지 목표)
- 캐싱 적용
- 최적화 완료

---

## Phase 8: 배포 (3일)

### 목표
- Railway 배포 (개발)
- Docker 이미지 생성
- 프로덕션 준비

### 체크리스트

#### 8.1 Dockerfile
```dockerfile
# Build stage
FROM gradle:8.5-jdk17 AS build
WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY src ./src
RUN gradle buildFatJar --no-daemon

# Run stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# JVM 최적화
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:+UseContainerSupport"

COPY --from=build /app/build/libs/*-all.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -q --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

#### 8.2 Railway 설정
```json
// railway.json
{
    "$schema": "https://railway.app/railway.schema.json",
    "build": {
        "builder": "DOCKERFILE"
    },
    "deploy": {
        "startCommand": "java -jar app.jar",
        "healthcheckPath": "/health",
        "healthcheckTimeout": 300
    }
}
```

#### 8.3 환경 변수
```
DATABASE_URL=jdbc:postgresql://...
DATABASE_USER=postgres
DATABASE_PASSWORD=***
SESSION_SECRET=***
```

#### 8.4 Health check 엔드포인트
```kotlin
get("/health") {
    call.respondText("OK")
}
```

#### 8.5 배포 체크리스트
- [ ] 환경 변수 설정
- [ ] DB 마이그레이션
- [ ] SSL 확인
- [ ] 도메인 연결 (선택)
- [ ] 모니터링 설정

#### 8.6 Oracle Cloud 마이그레이션 (나중에)
- [ ] VM 생성 (ARM 4코어/24GB)
- [ ] Docker 설치
- [ ] Nginx 리버스 프록시
- [ ] Let's Encrypt SSL
- [ ] GitHub Actions CI/CD

### 산출물
- Railway 배포 완료
- Docker 이미지
- 프로덕션 URL

---

## 추가 기능 (선택)

### 우선순위 높음
- [ ] 이미지 업로드 (Cloudinary)
- [ ] 댓글 시스템 (Giscus 또는 자체)
- [ ] 다크 모드

### 우선순위 중간
- [ ] 구독 기능 (이메일)
- [ ] 소셜 공유 버튼
- [ ] 관련 글 추천
- [ ] 시리즈 기능

### 우선순위 낮음
- [ ] 다국어 지원
- [ ] PWA
- [ ] 오프라인 지원

---

## 학습 자료

### Kotlin
- [Kotlin 공식 문서](https://kotlinlang.org/docs/home.html)
- [Kotlin Koans](https://kotlinlang.org/docs/koans.html) (실습)

### Ktor
- [Ktor 공식 문서](https://ktor.io/docs/)
- [Ktor Samples](https://github.com/ktorio/ktor-samples)

### Exposed
- [Exposed Wiki](https://github.com/JetBrains/Exposed/wiki)
- [Exposed GitHub](https://github.com/JetBrains/Exposed)

### kotlinx.html
- [kotlinx.html GitHub](https://github.com/Kotlin/kotlinx.html)

### Tailwind CSS
- [Tailwind 문서](https://tailwindcss.com/docs)

### HTMX
- [HTMX 문서](https://htmx.org/docs/)

---

## 마일스톤

| 마일스톤 | 완료 기준 | 예상 시점 |
|---------|----------|----------|
| **M1: Hello World** | Ktor 서버 실행 | 1주차 |
| **M2: DB 연결** | CRUD 동작 | 2주차 |
| **M3: 기본 UI** | 글 목록/상세 페이지 | 4주차 |
| **M4: 인증** | 로그인/어드민 접근 | 5주차 |
| **M5: 에디터** | 글 작성/수정 | 7주차 |
| **M6: 완성** | SEO, 배포 완료 | 9주차 |

---

## 체크리스트 요약

```
[ ] Phase 1: 프로젝트 셋업
[ ] Phase 2: 데이터베이스 & 모델
[ ] Phase 3: 기본 페이지 구현
[ ] Phase 4: 인증 시스템
[ ] Phase 5: 어드민 & 에디터
[ ] Phase 6: 검색 & SEO
[ ] Phase 7: 테스트 & 최적화
[ ] Phase 8: 배포
```

화이팅! 🚀
