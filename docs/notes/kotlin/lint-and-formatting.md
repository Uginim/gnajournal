# Kotlin 린트 & 포맷팅

## 개요

Kotlin 코드 품질을 위한 도구들:
- **ktlint**: 린트 + 포맷터 (가장 인기)
- **detekt**: 정적 분석 (코드 스멜 감지)
- **IntelliJ 내장**: IDE 검사

---

## ktlint

### 특징
- Kotlin 공식 스타일 가이드 기반
- 린트 + 자동 포맷팅
- 설정 없이 바로 사용 가능 (zero-config)
- Gradle 플러그인 지원

### 설치 (Gradle)

```kotlin
// build.gradle.kts
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}
```

### 사용법

```bash
# 린트 검사
./gradlew ktlintCheck

# 자동 포맷팅
./gradlew ktlintFormat
```

### 검사 항목 예시

```kotlin
// ❌ 잘못된 코드
fun foo(){  // 중괄호 앞 공백 없음
    val x=1  // = 주변 공백 없음
    if(x>0){ }  // 괄호 주변 공백
}

// ✅ 올바른 코드
fun foo() {
    val x = 1
    if (x > 0) { }
}
```

### 주요 규칙

| 규칙 | 설명 |
|------|------|
| `no-wildcard-imports` | `import *` 금지 |
| `no-unused-imports` | 미사용 import 금지 |
| `indent` | 들여쓰기 4칸 |
| `max-line-length` | 최대 줄 길이 (기본 무제한) |
| `trailing-comma` | 후행 쉼표 |
| `no-empty-first-line-in-class-body` | 클래스 첫 줄 빈 줄 금지 |

### 설정 파일 (.editorconfig)

```ini
# .editorconfig
[*.{kt,kts}]
ktlint_code_style = ktlint_official
max_line_length = 120
ktlint_standard_no-wildcard-imports = disabled
```

### Git Hook 설정

```kotlin
// build.gradle.kts
ktlint {
    filter {
        exclude("**/generated/**")
    }
}

// 커밋 전 자동 검사
tasks.register("installGitHook", Copy::class) {
    from("scripts/pre-commit")
    into(".git/hooks")
}
```

---

## detekt

### 특징
- 정적 코드 분석
- 코드 스멜, 복잡도, 잠재적 버그 감지
- ktlint보다 더 깊은 분석

### 설치

```kotlin
// build.gradle.kts
plugins {
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}

detekt {
    config.setFrom(files("config/detekt.yml"))
    buildUponDefaultConfig = true
}
```

### 사용법

```bash
# 분석 실행
./gradlew detekt

# 리포트 생성
./gradlew detektGenerateConfig  # 설정 파일 생성
```

### 검사 항목

| 카테고리 | 예시 |
|---------|------|
| **complexity** | 함수가 너무 길다, 파라미터 너무 많다 |
| **empty-blocks** | 빈 catch, 빈 if |
| **exceptions** | 너무 넓은 예외 처리 |
| **naming** | 네이밍 규칙 위반 |
| **performance** | 비효율적인 코드 |
| **potential-bugs** | 잠재적 버그 |
| **style** | 스타일 위반 |

### 설정 예시 (detekt.yml)

```yaml
# config/detekt.yml
complexity:
  LongMethod:
    threshold: 60
  LongParameterList:
    functionThreshold: 6

style:
  MagicNumber:
    active: false  # 매직 넘버 검사 비활성화
  MaxLineLength:
    maxLineLength: 120

naming:
  FunctionNaming:
    functionPattern: '[a-z][a-zA-Z0-9]*'
```

---

## ktlint vs detekt

| | ktlint | detekt |
|--|--------|--------|
| 목적 | 포맷팅 + 기본 린트 | 정적 분석 |
| 설정 | 거의 불필요 | 세밀한 설정 가능 |
| 자동 수정 | ✅ `ktlintFormat` | ❌ (일부만) |
| 분석 깊이 | 스타일 위주 | 복잡도, 버그 감지 |
| 속도 | 빠름 | 느림 |

### 권장: 둘 다 사용

```kotlin
// build.gradle.kts
plugins {
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
    id("io.gitlab.arturbosch.detekt") version "1.23.4"
}
```

- **ktlint**: 포맷팅, 기본 스타일
- **detekt**: 코드 품질, 복잡도

---

## IntelliJ 연동

### ktlint 스타일 적용

```bash
# IntelliJ 코드 스타일을 ktlint에 맞춤
./gradlew ktlintApplyToIdea
```

### 저장 시 자동 포맷

1. Settings > Tools > Actions on Save
2. "Reformat code" 체크
3. "Optimize imports" 체크

### detekt 플러그인

1. Settings > Plugins
2. "Detekt" 검색 및 설치
3. 실시간 검사 활성화

---

## CI/CD 통합

### GitHub Actions

```yaml
# .github/workflows/lint.yml
name: Lint

on: [push, pull_request]

jobs:
  ktlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'corretto'
      - name: Run ktlint
        run: ./gradlew ktlintCheck
      - name: Run detekt
        run: ./gradlew detekt
```

---

## 현재 프로젝트에 적용

### 1. 플러그인 추가

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.20"
    id("io.ktor.plugin") version "3.3.2"
    id("org.jetbrains.kotlin.plugin.serialization") version "2.2.20"
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"  // 추가
}
```

### 2. .editorconfig 생성

```ini
# .editorconfig
root = true

[*]
charset = utf-8
end_of_line = lf
indent_size = 4
indent_style = space
insert_final_newline = true
trim_trailing_whitespace = true

[*.{kt,kts}]
ktlint_code_style = ktlint_official
max_line_length = 120
```

### 3. 사용

```bash
# 검사
./gradlew ktlintCheck

# 자동 수정
./gradlew ktlintFormat
```

---

## 참고

- [ktlint 공식](https://pinterest.github.io/ktlint/)
- [detekt 공식](https://detekt.dev/)
- [Kotlin 코딩 컨벤션](https://kotlinlang.org/docs/coding-conventions.html)