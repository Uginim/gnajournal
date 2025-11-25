# Java Class File Version

## 개념

Java 클래스 파일(`.class`)의 **바이너리 형식 버전 번호**이다.

Java 컴파일러가 `.java` 파일을 `.class` 파일로 변환할 때, 클래스 파일 헤더에 버전 번호가 기록된다. JVM은 실행 시 이 번호를 확인하여 자신이 지원하는 버전인지 검증한다.

## 버전 매핑표

| Class File Version | Java 버전 |
|-------------------|----------|
| 52 | Java 8 |
| 55 | Java 11 |
| 61 | Java 17 |
| 65 | Java 21 |
| 67 | Java 23 |

## 흔한 에러

```
java.lang.UnsupportedClassVersionError: MyClass has been compiled by
a more recent version of the Java Runtime (class file version 67.0),
this version of the Java Runtime only recognizes class file versions up to 55.0
```

### 에러 의미

- 클래스가 Java 23 (version 67)으로 컴파일됨
- 실행하려는 JVM은 Java 11 (version 55)까지만 지원
- **상위 버전으로 컴파일된 클래스는 하위 버전 JVM에서 실행 불가**

## 해결 방법

### 1. 실행 환경 Java 버전 올리기

컴파일된 버전과 동일하거나 상위 버전의 JDK/JRE 설치

### 2. 빌드 타겟 버전 낮추기

`build.gradle.kts`에서 JVM 타겟 설정:

```kotlin
kotlin {
    jvmToolchain(17)  // Java 17로 컴파일
}
```

또는:

```kotlin
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "17"
    }
}
```

## 참고

- 하위 호환성: Java는 상위 버전 JVM에서 하위 버전 클래스 파일 실행 가능
- 상위 호환성: 불가능 (하위 버전 JVM에서 상위 버전 클래스 파일 실행 불가)