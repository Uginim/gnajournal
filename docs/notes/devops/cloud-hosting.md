# 클라우드 호스팅 비교

## 개인 블로그용 호스팅 선택

```mermaid
graph TB
    Goal[목표] --> Free["무료 원함"]
    Goal --> Stable["안정성 원함"]

    Free --> FlyNeon["Fly.io + Neon + R2"]
    Stable --> RailwayR2["Railway + R2"]
```

---

## 호스팅 서비스 비교

| 서비스 | 무료 티어 | 유료 시작 | 슬립 모드 | 난이도 |
|--------|----------|----------|----------|--------|
| **Fly.io** | 3 VM, 256MB | $0~ | O (15분) | 보통 |
| **Railway** | 없음 | $5/월 | X | 쉬움 |
| **Render** | 750시간/월 | $7/월 | O (15분) | 쉬움 |
| **Heroku** | 없음 | $5/월 | X | 쉬움 |

---

## 데이터베이스 비교

| 서비스 | 무료 한도 | 슬립 | 특징 |
|--------|----------|------|------|
| **Neon** | 512MB, 무제한 | X | Serverless PostgreSQL |
| **Supabase** | 500MB | X | PostgreSQL + 부가기능 |
| **Railway** | 포함 (500MB) | X | 앱과 함께 관리 |
| **PlanetScale** | 5GB | X | MySQL only |

---

## 추천 조합

### 1. 완전 무료: Fly.io + Neon + R2

```mermaid
graph LR
    subgraph Free["$0/월"]
        Fly[Fly.io] --> App[Ktor]
        Neon[Neon] --> DB[(PostgreSQL)]
        R2[Cloudflare R2] --> Media[이미지]
    end
```

| 서비스 | 무료 한도 |
|--------|----------|
| Fly.io | 3 VM, 256MB RAM |
| Neon | 512MB DB |
| Cloudflare R2 | 10GB 저장 |

**단점**: Fly.io 슬립 모드 (첫 요청 5~10초 지연)

**해결**: UptimeRobot으로 5분마다 핑

### 2. 저렴 + 안정: Railway + R2

```mermaid
graph LR
    subgraph Paid["$5~/월"]
        Railway[Railway] --> App[Ktor]
        Railway --> DB[(PostgreSQL)]
        R2[Cloudflare R2] --> Media[이미지]
    end
```

| 항목 | 비용 |
|------|------|
| Railway Hobby | $5/월 |
| PostgreSQL | 포함 |
| Cloudflare R2 | $0 (10GB 무료) |
| **총합** | **$5/월** |

**장점**: 슬립 없음, 설정 간단, DB 포함

---

## Fly.io 설정

### fly.toml

```toml
app = "gnajournal-blog"
primary_region = "nrt"  # 도쿄

[build]
  dockerfile = "docker/Dockerfile"

[env]
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256
```

### 배포

```bash
# 설치
curl -L https://fly.io/install.sh | sh

# 로그인
fly auth login

# 앱 생성
fly launch

# 시크릿 설정
fly secrets set DATABASE_URL="postgresql://..."
fly secrets set R2_ACCESS_KEY="..."

# 배포
fly deploy
```

---

## Neon 설정

### 1. 프로젝트 생성
- [neon.tech](https://neon.tech) 가입
- New Project → Region: Asia (Singapore)

### 2. 연결 문자열
```
postgresql://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/blog?sslmode=require
```

### 3. Ktor 설정
```yaml
# application.yaml
database:
  url: ${DATABASE_URL}
  driver: org.postgresql.Driver
```

---

## Railway 설정

### 1. 프로젝트 생성
- [railway.app](https://railway.app) GitHub 연동
- New Project → Deploy from GitHub repo

### 2. PostgreSQL 추가
- New → Database → PostgreSQL
- 자동으로 `DATABASE_URL` 환경변수 생성

### 3. 환경 변수
```
DATABASE_URL=자동 생성
R2_ACCESS_KEY=직접 입력
R2_SECRET_KEY=직접 입력
```

### 4. 도메인 연결
- Settings → Domains → Add Custom Domain
- Namecheap DNS에서 CNAME 설정

---

## 슬립 모드 해결 (Fly.io)

### UptimeRobot 설정
1. [uptimerobot.com](https://uptimerobot.com) 가입 (무료)
2. Add New Monitor
   - Monitor Type: HTTP(s)
   - URL: https://gnajournal.com/health
   - Interval: 5 minutes

### Health 엔드포인트

```kotlin
get("/health") {
    call.respondText("OK")
}
```

---

## 비용 요약

| 구성 | 월 비용 | 적합한 경우 |
|------|--------|------------|
| Fly + Neon + R2 | $0 | 취미, 실험 |
| Railway + R2 | $5 | 실 서비스 |
| AWS/GCP | $10~30 | 대규모 |

---

## 결론

| 상황 | 추천 |
|------|------|
| **돈 쓰기 싫다** | Fly.io + Neon + R2 |
| **안정적 운영** | Railway + R2 |
| **회사/대규모** | AWS, GCP |

개인 블로그는 **Fly.io + Neon + R2 (무료)** 또는 **Railway + R2 ($5)** 둘 다 충분합니다.