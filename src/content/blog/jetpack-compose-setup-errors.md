---
title: 'Jetpack Compose 초기 세팅에서 만난 빌드 에러 4가지'
description: 'Compose 프로젝트를 세팅하며 마주친 네 가지 빌드 환경 문제와 해결법을 정리합니다. Empty Activity 템플릿, AAR metadata의 SDK 요구, mutableStateOf import, Gradle Wrapper 버전.'
pubDate: 'Jul 23 2026'
heroImage: '../../assets/blog-placeholder-1.jpg'
tags: ['Android', 'Jetpack Compose', 'Gradle', '빌드']
draft: true
---

Compose로 새 프로젝트를 시작할 때는 UI 코드보다 빌드 환경에서 먼저 막히는 경우가 많습니다. Android Studio 버전, Gradle 버전, AndroidX 라이브러리 버전이 서로 맞물려 있기 때문입니다. Compose 프로젝트를 세팅하면서 실제로 마주친 네 가지 상황과 각각을 어떻게 넘겼는지 정리했습니다.

## Empty Compose Activity가 Empty Activity로 이름이 바뀜

예전 자료는 New Project 화면에서 **Empty Compose Activity** 템플릿을 고르라고 합니다. 그런데 최신 Android Studio에는 그 항목이 없습니다.

최신 버전에서는 Compose 세팅이 기본값이 되면서 템플릿 이름이 **Empty Activity**로 바뀌었습니다. `Empty Activity`를 선택하면 Compose가 구성된 프로젝트가 생성됩니다. 예전의 `Empty Views Activity`가 오히려 전통적인 XML 레이아웃 기반 템플릿입니다.

- 최신 Android Studio에서 Compose 기본: `Empty Activity`
- XML(뷰) 기반이 필요하면: `Empty Views Activity`

## compileSdk 34에서 SDK 35를 요구하는 AAR metadata 오류

의존성을 최신으로 올렸더니 빌드가 아래 오류로 실패했습니다.

```
4 issues were found when checking AAR metadata:

  1.  Dependency 'androidx.core:core-ktx:1.16.0-rc01' requires libraries and
      applications that depend on it to compile against version 35 or later of
      the Android APIs.

      :app is currently compiled against android-34.

  2.  Dependency 'androidx.core:core-ktx:1.16.0-rc01' requires Android Gradle
      plugin 8.6.0 or higher. This build currently uses Android Gradle plugin 8.1.1.
  ...
```

메시지는 길지만 요구사항은 두 가지입니다.

- 이 라이브러리는 `compileSdk` 35 이상에서 컴파일해야 합니다. 지금 프로젝트는 android-34로 컴파일 중입니다.
- 이 라이브러리는 Android Gradle Plugin(AGP) 8.6.0 이상을 요구합니다. 지금은 8.1.1을 쓰고 있습니다.

원인은 단순합니다. 최신 AndroidX 라이브러리(`androidx.core` 1.16.x 등)를 끌어왔는데, 프로젝트의 `compileSdk`와 AGP 버전이 그 라이브러리를 감당할 만큼 올라가 있지 않은 것입니다.

세 가지 SDK 버전은 각각 따로 올릴 수 있습니다.

- `compileSdk`: 어떤 API로 컴파일할지 정합니다. 새 API 사용 가능 여부를 결정합니다.
- `targetSdk`: 어떤 런타임 동작에 옵트인할지 정합니다.
- `minSdk`: 앱을 설치할 수 있는 최소 기기 버전입니다.

`compileSdk`만 올린다고 곧바로 새 런타임 동작이 켜지거나 설치 가능 기기 범위가 바뀌지는 않습니다. 라이브러리 요구사항을 맞추려면 우선 `compileSdk`를 올리는 것으로 충분한 경우가 많습니다.

해결하려면 AGP를 라이브러리가 요구하는 버전(8.6.0 이상)으로 올리고, `compileSdk`를 35로 올려야 합니다.

```kotlin
android {
    compileSdk = 35   // 34 -> 35

    defaultConfig {
        targetSdk = 35
        minSdk = 24
    }
}
```

당장 SDK를 올리기 어렵다면, 반대로 라이브러리 버전을 프로젝트가 감당 가능한 선까지 내리는 것도 임시방편이 됩니다. 다만 장기적으로는 툴체인을 함께 올리는 편이 낫습니다.

## mutableStateOf가 오류로 표시됨

`remember { mutableStateOf(...) }`를 썼는데 IDE가 빨간 줄로 오류를 표시하는 경우가 있습니다. 대개 `by` 위임(delegate)에 필요한 import가 빠졌기 때문입니다.

```kotlin
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember

@Composable
fun Counter() {
    // by 위임을 쓰려면 getValue, setValue import가 필요하다
    var count by remember { mutableStateOf(0) }

    Button(onClick = { count++ }) {
        Text("clicked $count times")
    }
}
```

`by`를 쓰지 않고 `var state = remember { mutableStateOf(0) }`처럼 직접 받으면 `state.value`로 접근하며, 이때는 `getValue`와 `setValue` import가 필요 없습니다. 반대로 `by`를 쓰면 두 import가 없을 때 delegate가 없다는 오류가 납니다. 대부분 IDE 자동 import(Alt 또는 Option+Enter)로 해결되므로, 오류가 뜨면 import부터 확인해야 합니다.

## Gradle 버전은 wrapper 파일 한 줄로 바꿈

AGP를 올리면 그에 맞춰 Gradle 버전도 올려야 합니다. 건드릴 파일은 `gradle/wrapper/gradle-wrapper.properties` 하나입니다.

```properties
# 변경 전
distributionUrl=https\://services.gradle.org/distributions/gradle-8.0-bin.zip

# 변경 후
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-bin.zip
```

`distributionUrl`의 버전 문자열(`gradle-8.0-bin.zip`을 `gradle-8.6-bin.zip`으로)만 바꾸면, 다음 빌드 때 래퍼가 해당 버전을 내려받아 적용합니다. 프로젝트마다 Gradle을 따로 설치하지 않고 이 파일 한 줄로 버전을 관리하는 것이 Gradle Wrapper의 장점입니다.

주의할 점은 AGP 버전과 Gradle 버전에 호환 표가 정해져 있다는 것입니다. AGP 8.6은 특정 Gradle 최소 버전을 요구하므로, AGP만 올리고 Gradle을 그대로 두면 다른 오류가 납니다. 둘은 함께 올려야 합니다.

## 정리

Compose 자체는 선언형 UI라 코드가 직관적입니다. 그런데 실제로 시간을 쓰게 되는 곳은 대개 버전 조합입니다.

- 라이브러리를 올렸는데 빌드가 깨지면, 대부분 `compileSdk`, AGP, Gradle 세 버전이 서로 안 맞은 것입니다.
- 오류 메시지의 "requires ... version X or later" 부분을 읽으면 필요한 버전이 거기 적혀 있습니다.

---

*이 글은 개인 학습 노트를 정리한 것으로, 버전 숫자는 작성 시점 기준입니다. 실제 적용 시에는 사용하는 라이브러리의 릴리스 노트와 AGP, Gradle 호환 표를 함께 확인하세요.*
