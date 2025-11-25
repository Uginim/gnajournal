# Java Language Level

## 개념

**Java 컴파일러가 허용하는 문법/기능의 버전**이다.

SDK(JDK) 버전과 별개로, 코드에서 어떤 Java 문법까지 사용할지 제한할 수 있다.

## SDK vs Language Level

| 구분 | 설명 |
|-----|------|
| **SDK (JDK)** | 실제 컴파일/실행에 사용하는 Java 버전 |
| **Language Level** | 코드에서 사용할 수 있는 문법 버전 |

### 예시

JDK 21을 사용하면서 Language Level을 17로 설정하면:
- Java 21로 컴파일
- 하지만 17까지의 문법만 허용
- 21에서 추가된 문법 사용 시 컴파일 에러

## 버전별 주요 기능

| Language Level | 추가된 주요 기능 |
|---------------|----------------|
| 8 | Lambda, Stream API, Optional |
| 11 | `var` 키워드 (지역 변수) |
| 14 | Switch expressions |
| 16 | Records, Pattern matching for instanceof |
| 17 | Sealed classes |
| 21 | Record patterns, Virtual threads, Sequenced collections |

## IntelliJ 설정 방법

1. **File > Project Structure > Project**
2. **Language Level** 드롭다운에서 선택

## 권장 사항

- SDK와 Language Level을 **동일하게** 맞추는 것이 일반적
- 하위 호환성이 필요한 경우에만 Language Level을 낮게 설정
- 예: Corretto 21 사용 시 → Language Level도 21로 설정

## Gradle에서 설정

```kotlin
// build.gradle.kts
kotlin {
    jvmToolchain(21)
}

// 또는 Java 프로젝트의 경우
java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}
```
