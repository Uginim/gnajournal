# Docker 프로젝트 구성

## 프로젝트 파일 구조

```
project-root/
├── docker/
│   ├── Dockerfile              # 애플리케이션 이미지
│   ├── Dockerfile.dev          # 개발용 이미지 (선택)
│   └── nginx/
│       └── nginx.conf          # Nginx 설정 (필요 시)
├── docker-compose.yml          # 로컬 개발용
├── docker-compose.prod.yml     # 프로덕션용 (선택)
├── .dockerignore               # Docker 빌드 제외 파일
└── src/
    └── ...
```

---

## 기본 파일 구성

### 1. Dockerfile (멀티스테이지 빌드)

```dockerfile
# docker/Dockerfile

# Stage 1: Build
FROM gradle:8.5-jdk21 AS build
WORKDIR /app

# Gradle 캐시를 위해 의존성 먼저 복사
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || true

# 소스 복사 및 빌드
COPY src ./src
RUN gradle shadowJar --no-daemon

# Stage 2: Run
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# 빌드된 JAR 복사
COPY --from=build /app/build/libs/*-all.jar app.jar

# 환경 변수
ENV PORT=8080

# 포트 노출
EXPOSE 8080

# 실행
CMD ["java", "-jar", "app.jar"]
```

### 2. docker-compose.yml (로컬 개발)

```yaml
services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=jdbc:postgresql://db:5432/blog
      - DATABASE_USER=blog
      - DATABASE_PASSWORD=blog123
    depends_on:
      db:
        condition: service_healthy
    networks:
      - blog-network

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: blog
      POSTGRES_USER: blog
      POSTGRES_PASSWORD: blog123
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U blog"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - blog-network

  # 선택: 통계용 Umami
  umami:
    image: ghcr.io/umami-software/umami:postgresql-latest
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://umami:umami@umami-db:5432/umami
      DATABASE_TYPE: postgresql
      APP_SECRET: your-secret-key-here
    depends_on:
      - umami-db
    networks:
      - blog-network

  umami-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: umami
      POSTGRES_USER: umami
      POSTGRES_PASSWORD: umami
    volumes:
      - umami-data:/var/lib/postgresql/data
    networks:
      - blog-network

volumes:
  postgres-data:
  umami-data:

networks:
  blog-network:
    driver: bridge
```

### 3. .dockerignore

```
# Gradle
.gradle/
build/
!build/libs/*-all.jar

# IDE
.idea/
*.iml
.vscode/

# Git
.git/
.gitignore

# Docker
docker-compose*.yml
Dockerfile*

# 기타
*.md
docs/
*.log
.env.local
```

---

## 개발용 docker-compose (핫 리로드)

```yaml
# docker-compose.dev.yml
services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile.dev
    ports:
      - "8080:8080"
    volumes:
      - ./src:/app/src:ro
      - ./build.gradle.kts:/app/build.gradle.kts:ro
    environment:
      - DATABASE_URL=jdbc:postgresql://db:5432/blog
      - DATABASE_USER=blog
      - DATABASE_PASSWORD=blog123
    depends_on:
      - db
    command: gradle run --continuous

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: blog
      POSTGRES_USER: blog
      POSTGRES_PASSWORD: blog123
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

---

## 환경 변수 관리

### .env 파일 (Git에 커밋하지 않음)

```bash
# .env
DATABASE_URL=jdbc:postgresql://db:5432/blog
DATABASE_USER=blog
DATABASE_PASSWORD=secret-password

# OAuth
GOOGLE_CLIENT_ID=xxx
GOOGLE_CLIENT_SECRET=xxx
KAKAO_CLIENT_ID=xxx
KAKAO_CLIENT_SECRET=xxx

# 기타
APP_SECRET=your-app-secret
```

### docker-compose에서 사용

```yaml
services:
  app:
    env_file:
      - .env
```

---

## Ktor 설정 변경

### application.yaml (환경 변수 사용)

```yaml
ktor:
  application:
    modules:
      - com.gnajournal.blog.ApplicationKt.module
  deployment:
    port: ${PORT:8080}

database:
  url: ${DATABASE_URL:jdbc:h2:mem:test;DB_CLOSE_DELAY=-1}
  user: ${DATABASE_USER:root}
  password: ${DATABASE_PASSWORD:}
  driver: ${DATABASE_DRIVER:org.h2.Driver}
```

### build.gradle.kts (Shadow JAR 추가)

```kotlin
plugins {
    kotlin("jvm") version "2.2.20"
    id("io.ktor.plugin") version "3.3.2"
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.20"
    id("com.github.johnrengelman.shadow") version "8.1.1"  // 추가
}

ktor {
    fatJar {
        archiveFileName.set("app-all.jar")
    }
}
```

---

## 실행 명령어

```bash
# 로컬 개발 (PostgreSQL + App)
docker compose up -d

# 빌드 후 실행
docker compose up --build -d

# 로그 확인
docker compose logs -f app

# 종료
docker compose down

# 볼륨까지 삭제
docker compose down -v

# DB만 실행 (로컬에서 앱 실행 시)
docker compose up -d db
```

---

## 프로덕션 배포 (Railway)

Railway는 Dockerfile을 자동 감지하므로 별도 설정 불필요.

```yaml
# railway.toml (선택)
[build]
dockerfilePath = "docker/Dockerfile"

[deploy]
startCommand = "java -jar app.jar"
healthcheckPath = "/health"
```

---

## 흐름도

```mermaid
graph TB
    subgraph Local["로컬 개발"]
        DC[docker-compose.yml]
        App[Ktor App]
        DB[(PostgreSQL)]
    end

    subgraph Build["빌드 프로세스"]
        Gradle[Gradle Build]
        Shadow[Shadow JAR]
        Image[Docker Image]
    end

    subgraph Deploy["배포"]
        Railway[Railway]
        Domain[커스텀 도메인]
    end

    DC --> App
    DC --> DB
    App --> DB

    Gradle --> Shadow
    Shadow --> Image
    Image --> Railway
    Railway --> Domain
```

---

## 참고

- [Ktor Docker 문서](https://ktor.io/docs/docker.html)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [Railway 배포](https://docs.railway.app/)