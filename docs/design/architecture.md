# 시스템 아키텍처

## 전체 구조

```mermaid
graph TB
    subgraph Client
        Browser[브라우저]
    end

    subgraph Server["Ktor Server"]
        Router[Routing]
        Plugins[Plugins]

        subgraph Routes
            HomeRoute[Home]
            PostRoute[Post]
            AuthRoute[Auth]
            AdminRoute[Admin]
        end

        subgraph Services
            PostService[PostService]
            UserService[UserService]
            AuthService[AuthService]
            MarkdownService[MarkdownService]
        end

        subgraph Repositories
            PostRepo[PostRepository]
            UserRepo[UserRepository]
            TagRepo[TagRepository]
            CategoryRepo[CategoryRepository]
        end
    end

    subgraph Database
        PostgreSQL[(PostgreSQL)]
    end

    Browser -->|HTTP| Router
    Router --> Plugins
    Plugins --> Routes
    Routes --> Services
    Services --> Repositories
    Repositories -->|Exposed ORM| PostgreSQL
```

---

## 요청 흐름

```mermaid
sequenceDiagram
    participant B as Browser
    participant R as Router
    participant P as Plugins
    participant S as Service
    participant Repo as Repository
    participant DB as Database

    B->>R: GET /posts
    R->>P: 인증, 로깅, 압축
    P->>S: getPublishedPosts()
    S->>Repo: findAllPublished()
    Repo->>DB: SELECT * FROM posts
    DB-->>Repo: ResultSet
    Repo-->>S: List<Post>
    S-->>P: List<PostDto>
    P-->>R: HTML Response
    R-->>B: 200 OK + HTML
```

---

## 레이어 구조

```mermaid
graph LR
    subgraph Presentation["Presentation Layer"]
        Routes[Routes]
        Templates[HTML Templates]
    end

    subgraph Business["Business Layer"]
        Services[Services]
    end

    subgraph Data["Data Layer"]
        Repositories[Repositories]
        Entities[Tables/Entities]
    end

    subgraph Infrastructure["Infrastructure"]
        Database[(Database)]
        Config[Configuration]
        Plugins[Ktor Plugins]
    end

    Routes --> Services
    Services --> Repositories
    Repositories --> Database
    Routes --> Templates
    Plugins -.-> Routes
    Config -.-> Plugins
```

---

## 디렉토리 구조 (목표)

```
src/main/kotlin/net/gnajournal/blog/
├── Application.kt          # 진입점
├── plugins/                 # Ktor 플러그인 설정
│   ├── Routing.kt
│   ├── Security.kt
│   ├── Serialization.kt
│   ├── HTTP.kt
│   └── Database.kt
├── routes/                  # HTTP 라우트
│   ├── HomeRoutes.kt
│   ├── PostRoutes.kt
│   ├── AuthRoutes.kt
│   └── AdminRoutes.kt
├── services/                # 비즈니스 로직
│   ├── PostService.kt
│   ├── UserService.kt
│   ├── AuthService.kt
│   └── MarkdownService.kt
├── repositories/            # 데이터 접근
│   ├── PostRepository.kt
│   ├── UserRepository.kt
│   ├── TagRepository.kt
│   └── CategoryRepository.kt
├── models/                  # 테이블 정의
│   ├── Posts.kt
│   ├── Users.kt
│   ├── Tags.kt
│   └── Categories.kt
├── dto/                     # Data Transfer Objects
│   ├── PostDto.kt
│   ├── UserDto.kt
│   └── ...
├── templates/               # HTML DSL 템플릿
│   ├── Layout.kt
│   ├── pages/
│   └── components/
└── utils/                   # 유틸리티
    ├── PasswordUtil.kt
    └── SlugUtil.kt
```

---

## 기술 스택

```mermaid
graph TB
    subgraph Frontend
        HTML[kotlinx.html DSL]
        Tailwind[Tailwind CSS]
        HTMX[HTMX]
    end

    subgraph Backend
        Kotlin[Kotlin 2.2]
        Ktor[Ktor 3.3]
        Exposed[Exposed ORM]
    end

    subgraph Infrastructure
        Netty[Netty Server]
        PostgreSQL[(PostgreSQL)]
        Docker[Docker]
    end

    HTML --> Ktor
    Tailwind --> HTML
    HTMX --> Ktor
    Kotlin --> Ktor
    Ktor --> Netty
    Exposed --> PostgreSQL
    Docker --> Netty
    Docker --> PostgreSQL
```