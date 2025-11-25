# IntelliJ JDK 설정 가이드

## IntelliJ에서 확인해야 할 JDK 설정들

IntelliJ에서 Java/Kotlin 프로젝트를 실행할 때 **3가지 JDK 설정**이 있다.

### 1. Project SDK

프로젝트 전체에서 사용하는 JDK

**설정 위치**: File > Project Structure > Project > SDK

### 2. Language Level

컴파일러가 허용하는 문법 버전

**설정 위치**: File > Project Structure > Project > Language Level

### 3. Gradle JVM (중요!)

**Gradle 빌드 시 사용하는 JDK**. 이 설정이 실제 컴파일에 사용된다.

**설정 위치**: Settings > Build, Execution, Deployment > Build Tools > Gradle > Gradle JVM

## 흔한 문제

### 에러 메시지
```
UnsupportedClassVersionError: has been compiled by a more recent version
of the Java Runtime (class file version 67.0), this version of the Java
Runtime only recognizes class file versions up to 65.0
```

### 원인
Project SDK는 21로 바꿨지만, **Gradle JVM**이 여전히 23을 사용 중

### 해결
1. Settings > Build Tools > Gradle > **Gradle JVM** → corretto-21로 변경
2. 또는 `build.gradle.kts`에 명시 (권장)

## IDE 설정 vs build.gradle.kts

| | IDE 설정만 | build.gradle.kts 명시 |
|--|----------|---------------------|
| 로컬 빌드 | 본인 PC만 적용 | 모든 환경 동일 |
| CI/CD | 별도 설정 필요 | 자동 적용 |
| 팀 협업 | 각자 설정 필요 | Git으로 공유됨 |
| 재현성 | 환경마다 다를 수 있음 | 보장됨 |

**권장**: IDE 설정과 함께 `build.gradle.kts`에도 명시

## build.gradle.kts 설정 방법

```kotlin
// Kotlin 프로젝트
kotlin {
    jvmToolchain(21)
}

// Java 프로젝트
java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}
```

## Homebrew로 설치한 JDK가 IntelliJ에서 안 보일 때

수동으로 추가:

1. File > Project Structure > SDKs
2. + 버튼 > Add JDK
3. 경로 입력:
   ```
   /Library/Java/JavaVirtualMachines/amazon-corretto-21.jdk/Contents/Home
   ```

## jenv와 IntelliJ

- **jenv**: 터미널에서 사용하는 Java 버전 관리 도구
- **IntelliJ**: 자체적으로 JDK 경로를 관리

jenv global 설정과 IntelliJ 설정은 **별개**이므로 각각 설정해야 한다.
