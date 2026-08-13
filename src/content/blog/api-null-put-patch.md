---
title: 'API 요청의 null은 무엇을 뜻하는가'
description: '수정 API에서 필드에 null을 넣는 것과 필드를 아예 빼는 것은 다릅니다. 서버가 필드 부재와 명시적 null을 구분하지 못하면 null 규칙을 정할 수 없습니다. Jackson의 동작과 패치 본문 형식을 로컬에서 실행해 확인했습니다.'
pubDate: 'Aug 14 2026'
tags: ['API', 'HTTP', 'REST', 'Jackson', 'Kotlin']
draft: false
---
예전에 특정 API의 값이 초기화되지 않는다는 리포팅을 받은 적이 있습니다.

코드를 열어 확인하니, 요청 DTO에 담긴 값을 엔티티로 옮기는 긴 함수가 있었습니다.
그런데 필드에 담긴 null을 처리하는 방식이 독특했습니다.
`?.let { }`처럼 null이 아닌 경우에만 스코프 함수 안에서 값을 옮기는 코드였습니다.

이 코드의 의도는 "프론트엔드가 보내지 않은 값은 수정하지 않겠다"였습니다.

## 요청 본문의 null이 필드마다 다른 뜻으로 처리됨

해당 API만 그런 것이 아니었습니다. 프로젝트 전반에 퍼져 있던 null 처리 코드를 일반화해 옮기면 이런 형태였습니다.

```kotlin
// 빈 문자열이어도 무시한다
request.name?.takeIf { it.isNotBlank() }?.let { this.name = it }

// null이면 무시한다
request.status?.let { this.status = it }
request.memo?.let { this.memo = it }

// null이면 무시한다
if (!request.startDate.isNullOrBlank()) {
    this.startDate = LocalDate.parse(request.startDate)
}

// null이면 비운다
if (request.endDate.isNullOrBlank()) {
    this.endDate = null
} else {
    this.endDate = LocalDate.parse(request.endDate)
}
```

같은 함수 안에서 null의 뜻이 둘로 갈립니다.


| 필드          | 구현                                  | null이 오면 |
| ----------- | ----------------------------------- | -------- |
| `name`      | `?.takeIf { it.isNotBlank() }?.let` | 무시       |
| `status`    | `?.let`                             | 무시       |
| `memo`      | `?.let`                             | 무시       |
| `startDate` | `if (!isNullOrBlank())`로 할당         | 무시       |
| `endDate`   | `if (isNullOrBlank())` 면 null 할당    | 비움       |


클라이언트 입장에서는 어느 필드에 null을 넣어야 지워지는지 알 방법이 없습니다. 서버 코드를 열어봐야 압니다.

값을 비우는 기능이 필요해진 시점에 이 상태가 문제가 됐습니다. 규칙을 하나로 맞추려면 null이 무엇을 뜻하는지부터 정해야 했습니다.

## 필드를 빼고 보낸 요청과 null로 보낸 요청이 같게 도착함

null을 비움으로 정하면 될 것 같았습니다. 그런데 그렇게 하면 클라이언트가 보내지 않은 필드까지 지워집니다. 서버에 도착하는 시점에 두 경우가 같아지기 때문입니다.

평범한 DTO에 두 입력을 넣어 봤습니다.

```kotlin
class PlainDto {
    var name: String? = null
    var age: Int? = null
}
```

```
[1] 평범한 DTO는 명시적 null과 필드 부재를 구분하지 못한다
  {"name":null,"age":30}  ->  name=null
  {"age":30}             ->  name=null
```

로컬에서 실행한 결과입니다. 전체 프로젝트는 부록에 있습니다.

`name`에 null을 넣어 보낸 요청과 `name`을 아예 빼고 보낸 요청이 같은 상태로 도착합니다. 서버 코드에서는 둘 다 `name == null`입니다. 지워달라는 요청과 건드리지 말라는 요청을 가를 근거가 없습니다.

## Jackson은 왜 필드 부재와 명시적 null을 구분하지 않나

이 문제를 처음 봤을 때는 타입 탓이라고 생각했습니다. 코틀린의 `String?`이 값과 null 두 상태만 담으니 세 번째 상태를 넣을 자리가 없다고 봤습니다.

조사해보니 GitHub의 Jackson 이슈 트래커에 답이 있었습니다. Jackson을 만든 Tatu Saloranta가 적어 둔 이유는 제 짐작과 달랐습니다.

> Jackson does not keep track of whether any given property has been set or not
>
> Jackson은 어떤 프로퍼티가 설정됐는지 아닌지를 추적하지 않는다.

같은 코멘트에서 왜 그렇게 하기 어려운지도 덧붙였습니다.

> the blocker is that change is very intrusive: due to explosion of code paths during deserialization new state has to be passed through multiple call chains. And this is necessary since deserializers are stateless (as they have to be to be shared between all concurrent calls).
>
> 걸림돌은 그 변경이 손대야 할 범위가 넓다는 점이다. 역직렬화 과정에서 코드 경로가 폭증하기 때문에, 새로운 상태를 여러 호출 사슬에 걸쳐 넘겨야 한다. 디시리얼라이저는 무상태이므로 이것이 불가피하다. 동시 호출 전부가 공유해야 해서 그렇게 설계할 수밖에 없다.

([jackson-databind 이슈 #443](https://github.com/FasterXML/jackson-databind/issues/443), 2014년)

"이 프로퍼티가 입력에 있었는가"라는 정보를 넘길 자리가 애초에 없다는 뜻입니다.

타입의 표현력이 아니라 바인딩 구조의 문제였습니다.

그래서 Jackson에는 부재를 다루는 경로가 둘로 갈립니다.

> for setters and fields there simply is no call and no processing occurs
>
> 세터와 필드의 경우에는 호출 자체가 일어나지 않고 아무 처리도 되지 않는다.

([jackson-modules-java8 이슈 #229](https://github.com/FasterXML/jackson-modules-java8/issues/229))


| 바인딩 경로   | 필드가 없으면                               | 명시적 null이면              |
| -------- | ------------------------------------- | ----------------------- |
| 필드, 세터   | 아무 호출도 일어나지 않고 초기값이 남음                | 값을 대입함                  |
| 생성자, 레코드 | 뭐라도 넘겨야 하므로 `getAbsentValue()` 결과를 넘김 | `getNullValue()` 결과를 넘김 |


생성자 경로에서 두 경우가 겹치는 이유는 `getAbsentValue()`의 기본 구현이 `getNullValue()`를 호출하기 때문입니다. 기본값이 같아서 합쳐질 뿐, 구조적으로 못 가르는 것은 아닙니다. 이 훅은 jackson-databind 2.13에 들어왔습니다.

## 필드 부재 여부를 구분하지 못하면 요청에 없는 필드가 null이 됨

구분하지 못하는 상태에서 "null이면 비움"을 규칙대로 구현하면 안 보낸 필드도 함께 비워집니다. 서버에게 두 요청은 같은 입력이니 달리 처리할 방법이 없습니다.

그리고 그 동작은 PUT이 정의하는 바와 일치합니다.

> The PUT method requests that the state of the target resource be created or replaced with the state defined by the representation enclosed in the request message content.
>
> PUT 메서드는 대상 리소스의 상태를, 요청 메시지 본문에 담긴 표현이 정의하는 상태로 생성하거나 교체할 것을 요청한다.

([RFC 9110 §9.3.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.4))

전체 교체라면 본문에 없는 필드가 남지 않는 것이 정상입니다.

반대로 넘겨받은 코드는 대부분의 필드에서 안 보낸 값을 유지하고 있었습니다. 엔드포인트는 PUT인데 동작은 부분 수정이었습니다.

전체 교체를 택하면 부담이 클라이언트로 갑니다. 한 필드만 바꾸려 해도 객체 전체를 정확히 보내야 합니다. 나중에 필드를 추가하면 그 필드를 모르는 기존 클라이언트가 수정할 때마다 값을 지웁니다. 오류가 나지 않고 데이터만 사라지므로 발견도 늦습니다.

## null 규칙을 어떻게 바꾸기로 했나

전체 교체로 규칙을 통일하는 선택지는 접었습니다. 프론트엔드가 어떤 상황에서 어떤 필드를 빼고 보내는지 파악하지 못한 상태였기 때문입니다. 규칙을 한 번에 바꾸면 그때까지 무시되던 값들이 삭제 명령으로 바뀝니다.

그렇다고 지금 상태를 유지할 수도 없었습니다. 같은 타입으로 선언된 필드의 null을 필드마다 다르게 해석하는 구조는 설명할 방법이 없었습니다.

그래서 규칙을 정하기 전에 필드 부재를 가려내는 일부터 하기로 방향을 잡았습니다. 구분하지 못하면 정할 수 있는 규칙이 이미 하나로 줄어 있습니다. 안 보낸 것과 null이 같은 입력인 이상, 둘을 다르게 대우하는 규칙은 선택지에 들어오지 않습니다. 규칙을 정했다고 생각하지만 실은 코드가 대신 정해 놓은 상태입니다.

## 부분 수정의 본문 형식은 PATCH가 정하고 있음

찾아보니 안 보낸 필드를 유지하는 것은 PUT의 영역이 아니었습니다. RFC 5789가 첫 절에서 그렇게 규정합니다.

> The PUT method is already defined to overwrite a resource with a complete new body, and cannot be reused to do partial changes.
>
> PUT 메서드는 리소스를 완전히 새로운 본문으로 덮어쓰도록 이미 정의되어 있으므로, 부분 변경에 재사용할 수 없다.

([RFC 5789 §1](https://www.rfc-editor.org/rfc/rfc5789.html#section-1))

부분 수정 요청의 본문 형식(patch format)도 따로 규정돼 있습니다. 그리고 형식마다 null의 뜻이 다릅니다.

JSON Merge Patch(RFC 7396)에서 null은 삭제입니다. 패치에 없는 멤버는 그대로 둡니다.

> If the provided merge patch contains members that do not appear within the target, those members are added. If the target does contain the member, the value is replaced. Null values in the merge patch are given special meaning to indicate the removal of existing values in the target.
>
> 주어진 머지 패치에 대상 문서에 없는 멤버가 들어 있으면 그 멤버를 추가한다. 대상 문서에 그 멤버가 있으면 값을 교체한다. 머지 패치의 null 값에는 특별한 의미가 부여되어, 대상 문서에 있던 값을 제거하라는 뜻이 된다.

([RFC 7396 §1](https://www.rfc-editor.org/rfc/rfc7396.html#section-1))

```
[3] JSON Merge Patch(RFC 7396)에서 null은 삭제다
  대상            : {"name":"Kim","age":30,"nick":"k"}
  패치 {"nick":null}  ->  {"name":"Kim","age":30}
  패치 {"age":31}  ->  {"name":"Kim","age":31,"nick":"k"}
```

`nick`에 null을 넣으니 사라졌고, `age`만 담은 패치에서는 `nick`이 남았습니다.

JSON Patch(RFC 6902)에서는 같은 null이 다른 뜻입니다. 본문이 연산 배열이고, `replace`의 값으로 준 null은 삭제가 아니라 null 설정입니다. 삭제는 `remove`라는 별도 연산입니다.

```
[4] JSON Patch(RFC 6902)는 삭제와 null 설정을 구분한다
  대상                              : {"name":"Kim","nick":"k"}
  [{"op":"replace","path":"/nick","value":null}]  ->  {"name":"Kim","nick":null}
  [{"op":"remove","path":"/nick"}]  ->  {"name":"Kim"}
```

같은 `null`이 한쪽에서는 필드를 지우고 다른 쪽에서는 필드를 null로 채웁니다. 어느 쪽이 옳은 것이 아니라, 어느 패치 형식을 쓰느냐가 뜻을 정합니다.

## 애플리케이션 공용 설정이 PATCH를 막고 있었음

그래서 PATCH로 바꾸려 했습니다. 그런데 요청이 통하지 않았습니다.

스프링이 PATCH를 지원하지 않는 것은 아닙니다. `@PatchMapping`은 Spring 4.3부터 있고 JSON 본문 PATCH는 그대로 동작합니다. 막고 있던 것은 애플리케이션의 공용 설정이었습니다. CORS 허용 메서드 목록과 시큐리티 인가 매처가 메서드를 열거식으로 관리하고 있었고, 거기에 PATCH가 없었습니다.

여기서 비대칭은 기술적인 것이 아니었습니다. 스프링의 기본 CORS 허용 메서드는 GET, HEAD, POST뿐이라 PUT도 기본으로는 열려 있지 않습니다. PUT이 쉬웠던 이유는 표준이 그래서가 아니라, 그 프로젝트의 공용 설정에 PUT이 이미 등재돼 있었기 때문입니다.

공용 설정을 바꾸는 일이라 백엔드 담당자와 상의했습니다. 담당자는 굳이 열어두지 않은 이유가 있지 않겠냐고 했습니다. 저도 그 이유를 확인하지 못한 상태였으므로 열지 않기로 했습니다.

## PATCH를 못 여는 상태에서 JsonNullable로 필드 부재를 가려내도록 조치함

메서드를 못 바꾸는 상태에서, 구분할 능력만 먼저 갖추기로 했습니다.

`JsonNullable`을 썼습니다. OpenAPI Tools가 만든 래퍼 타입입니다. OpenAPI Generator도 스펙에 nullable로 적힌 필드를 이 타입으로 만듭니다.

```kotlin
class NullableDto {
    var name: JsonNullable<String?> = JsonNullable.undefined()
    var age: JsonNullable<Int?> = JsonNullable.undefined()
}
```

```
[2] JsonNullable은 두 경우를 isPresent로 구분한다
  {"name":null,"age":30}  ->  isPresent=true, value=null
  {"age":30}             ->  isPresent=false
```

원리는 앞에서 본 `getAbsentValue()`입니다. 이 래퍼의 디시리얼라이저가 `getAbsentValue()`를 `undefined`로, `getNullValue()`를 `of(null)`로 오버라이드합니다. 기본값이 같아서 겹쳐 있던 두 경로를 갈라 놓는 것입니다.

서비스 코드에서는 도착 여부를 먼저 보고, 그 안에서 값이 null일 때만 비웁니다.

```kotlin
if (request.name.isPresent && request.name.get() == null) {
    this.name = null
}
```

`isPresent`가 false면 이 블록을 타지 않으므로 기존 값이 남습니다.

이 선택에는 정당화할 수 있는 부분과 그렇지 못한 부분이 같이 있습니다.

도구 쪽은 이 조합을 막지 않습니다. OpenAPI Generator가 `JsonNullable`로 감쌀지 정하는 기준은 스키마의 nullable 여부 하나뿐이고 HTTP 메서드는 보지 않습니다. PUT 오퍼레이션만 있는 스펙과 PATCH만 있는 스펙으로 각각 생성해 모델을 비교해 봤는데 동일했습니다. 달라지는 것은 API 인터페이스의 메서드뿐입니다.

문서로 같은 선택을 밝힌 서비스도 있습니다. FreeWheel Buzz는 PUT이 요청에 없는 필드를 덮어쓰지 않는다고 적고, 이렇게 덧붙입니다.

> In some REST API implementations this behavior is handled by the PATCH verb, but this is not currently supported in Buzz.
>
> 일부 REST API 구현에서는 이 동작을 PATCH 메서드가 담당하지만, Buzz는 현재 PATCH를 지원하지 않는다.

그러나 표준과 주요 설계 가이드는 일관되게 반대합니다. 앞서 인용한 RFC 5789가 정면으로 금하고, 나머지 셋도 같은 방향입니다.

> Because PUT is defined as a complete replacement of the content, it is dangerous for clients to use PUT to modify data.
>
> PUT은 내용을 통째로 교체하는 것으로 정의되어 있으므로, 클라이언트가 PUT으로 데이터를 수정하는 것은 위험하다.

([Microsoft REST API Guidelines §7.4.3](https://github.com/microsoft/api-guidelines/blob/master/Guidelines.md))

> Google APIs generally use the PATCH HTTP verb only, and do not support PUT requests.
>
> Google API는 일반적으로 PATCH만 쓰고 PUT 요청은 지원하지 않는다.

같은 문서는 전체 교체만 지원할 경우 PUT을 써도 되지만 권하지 않는다고 적습니다. 리소스에 필드를 추가하는 일이 하위호환을 깨는 변경이 되기 때문입니다.

> However, this is strongly discouraged because it becomes a backwards-incompatible change to add fields to the resource.
>
> 다만 이 방식은 강하게 권하지 않는다. 리소스에 필드를 추가하는 것이 하위호환을 깨는 변경이 되기 때문이다.

([Google AIP-134](https://google.aip.dev/134))

> If a request does not include all of the attributes for a resource, the server MUST interpret the missing attributes as if they were included with their current values. The server MUST NOT interpret missing attributes as null values.
>
> 요청이 리소스의 모든 속성을 담고 있지 않다면, 서버는 빠진 속성을 현재 값 그대로 담겨 있는 것으로 해석해야 한다. 서버는 빠진 속성을 null로 해석해서는 안 된다.

([JSON:API Updating Resources](https://jsonapi.org/format/#crud-updating))

여건 때문에 표준이 권하지 않는 쪽을 택한 것입니다. 도구가 막지 않는다고 해서 표준에 맞는 것은 아닙니다.

## JsonNullable 우회가 남긴 한계

- **표준 준수가 어려움**: 표준이 권하지 않는 선택입니다. PATCH를 열 수 있는 상황이라면 PATCH가 맞습니다. 공용 설정을 바꾸기 어려운 사정이 없다면 이 글의 우회를 따라할 이유가 없습니다.
- **적용 범위가 좁음**: 필요한 필드에만 래퍼를 씌웠으므로 한 DTO 안에 규칙이 섞여 있습니다. 이 패턴을 모르는 사람에게는 왜 어떤 필드만 다른지가 매번 질문거리가 됩니다.
- **기존 요청의 뜻이 바뀔 위험이 있음**: null 규칙을 바꾸면 지금까지 무시되던 명시적 null이 삭제 명령이 됩니다. 클라이언트가 안 건드릴 필드에 null을 넣어 보내고 있었다면 그 값들이 지워집니다. 적용 전에 어떤 필드로 명시적 null이 얼마나 들어오는지 측정해야 합니다.
- **확인한 버전이 한정됨**: Kotlin 1.9.0, jackson-databind 2.15.2, jackson-databind-nullable 0.2.6에서 확인했습니다. Jackson은 부재 처리 동작이 버전에 따라 바뀐 적이 있습니다. `Optional`의 경우 3.0.0에서 바뀌었다가 3.0.1에서 되돌아왔습니다. Spring Boot 4.0이 Jackson 3을 기본으로 채택했으므로 버전을 올릴 때는 다시 확인하는 편이 안전합니다.
- **라이브러리가 관리자를 찾고 있음**: `jackson-databind-nullable` 저장소 최상단에 그 공지가 있습니다.
- **공개 사례가 한쪽에 몰려 있음**: 널리 쓰이는 조합이라고 말할 근거는 없습니다. 공개 코드에서 PUT과 이 래퍼를 함께 쓴 사례를 찾아보면 나오기는 합니다. 다만 제가 찾아본 범위에서는 대부분 한 교육과정의 예제가 복제된 것이라, 여러 팀이 독립적으로 택한 결과로 읽으면 안 됩니다.

## 결론

null의 의미는 어느 패치 형식을 쓰느냐로 결정됩니다. Merge Patch에서 null은 삭제이고, JSON Patch에서 같은 null은 값 설정입니다. 규칙을 정하지 않으면 서버마다 뜻이 달라집니다.

그리고 규칙을 정하기 전에 필드 부재를 가려낼 수 있어야 합니다. 코드가 필드 부재와 명시적 null을 구분하지 못하면 정할 수 있는 규칙이 이미 하나로 줄어 있습니다.

정했다면 null은 확실하게 비움으로 처리해야 합니다. 가장 나쁜 상태는 처음에 본 그 코드처럼 필드마다 규칙이 다른 경우입니다. 그때는 클라이언트가 서버 코드를 열어봐야 동작을 알 수 있습니다.

## 부록 A. HTTP 메서드 하나를 여는 데 걸리는 계층

이 프로젝트의 공용 설정에 PATCH가 왜 열려 있지 않았는지는 끝내 알아내지 못했습니다. 초기 설정을 담당한 분에게 확인할 수 있는 상황이 아니었기 때문입니다. 당시에도 이유를 모른 채 보류했고, 지금도 근거를 찾지 못했습니다.

메서드 하나를 여는 데 관련되는 계층은 여럿입니다. CORS 허용 메서드 목록, 시큐리티 인가 매처, 그리고 구성에 따라 WAF 규칙입니다. 특히 인가를 메서드별로 거는 구조에서는 새 메서드가 어느 매처에도 걸리지 않아 종단 규칙으로 떨어질 수 있습니다. 그러면 차단되는 것이 아니라 권한 검사를 건너뛰게 됩니다. 이 부분은 따로 정리하겠습니다.

클라이언트 쪽에는 문서로 확인되는 제약이 하나 있습니다. `java.net.HttpURLConnection.setRequestMethod`의 허용 메서드 목록에 PATCH가 없습니다. 스프링 문서도 같은 사실을 적습니다.

> Note that the JDK HttpURLConnection does not support PATCH, but Apache HttpComponents and others do.
>
> JDK의 HttpURLConnection은 PATCH를 지원하지 않지만 Apache HttpComponents 등은 지원한다는 점에 유의한다.

([Spring Framework REST Clients](https://docs.spring.io/spring-framework/reference/integration/rest-clients.html))

다만 이것은 요청을 보내는 쪽 이야기라 서버 엔드포인트를 여는 문제와는 층이 다릅니다.

## 부록 B. 재현에 쓴 프로젝트

실제로 적용한 코드는 공개하기 어려워 데모로 대체했습니다. 아래 파일 세 개로 위 출력을 그대로 재현할 수 있습니다.

```
<프로젝트 폴더>/
  settings.gradle.kts
  build.gradle.kts
  src/main/kotlin/Main.kt
```

`settings.gradle.kts`

```kotlin
rootProject.name = "null-patch-demo"
```

`build.gradle.kts`

```kotlin
plugins {
    kotlin("jvm") version "1.9.0"
    application
}

repositories { mavenCentral() }

dependencies {
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.15.2")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.15.2")
    implementation("org.openapitools:jackson-databind-nullable:0.2.6")
}

kotlin { jvmToolchain(17) }

application { mainClass.set("MainKt") }
```

`src/main/kotlin/Main.kt`

```kotlin
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.ObjectNode
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import org.openapitools.jackson.nullable.JsonNullable
import org.openapitools.jackson.nullable.JsonNullableModule

// 평범한 DTO. 프로퍼티가 값과 null 두 상태만 담는다.
class PlainDto {
    var name: String? = null
    var age: Int? = null
}

// JsonNullable로 감싼 DTO. 세 상태를 담는다.
class NullableDto {
    var name: JsonNullable<String?> = JsonNullable.undefined()
    var age: JsonNullable<Int?> = JsonNullable.undefined()
}

fun main() {
    val mapper = ObjectMapper().registerKotlinModule().registerModule(JsonNullableModule())

    val withNull = """{"name":null,"age":30}"""
    val withoutKey = """{"age":30}"""

    println("[1] 평범한 DTO는 명시적 null과 필드 부재를 구분하지 못한다")
    mapper.readValue(withNull, PlainDto::class.java).let {
        println("  $withNull  ->  name=${it.name}")
    }
    mapper.readValue(withoutKey, PlainDto::class.java).let {
        println("  $withoutKey             ->  name=${it.name}")
    }
    println()

    println("[2] JsonNullable은 두 경우를 isPresent로 구분한다")
    mapper.readValue(withNull, NullableDto::class.java).name.let {
        println("  $withNull  ->  isPresent=${it.isPresent}, value=${if (it.isPresent) it.get() else "-"}")
    }
    mapper.readValue(withoutKey, NullableDto::class.java).name.let {
        println("  $withoutKey             ->  isPresent=${it.isPresent}")
    }
    println()

    val target = """{"name":"Kim","age":30,"nick":"k"}"""

    println("[3] JSON Merge Patch(RFC 7396)에서 null은 삭제다")
    println("  대상            : $target")
    listOf("""{"nick":null}""", """{"age":31}""").forEach { patch ->
        val result = mergePatch(mapper.readTree(target), mapper.readTree(patch), mapper)
        println("  패치 $patch  ->  $result")
    }
    println()

    val target2 = """{"name":"Kim","nick":"k"}"""

    println("[4] JSON Patch(RFC 6902)는 삭제와 null 설정을 구분한다")
    println("  대상                              : $target2")
    listOf(
        """[{"op":"replace","path":"/nick","value":null}]""",
        """[{"op":"remove","path":"/nick"}]""",
    ).forEach { ops ->
        val result = jsonPatch(mapper.readTree(target2) as ObjectNode, mapper.readTree(ops))
        println("  $ops  ->  $result")
    }
}

// RFC 7396의 MergePatch 알고리즘을 그대로 옮긴 것.
fun mergePatch(target: JsonNode, patch: JsonNode, mapper: ObjectMapper): JsonNode {
    if (!patch.isObject) return patch
    val result = if (target.isObject) target.deepCopy<ObjectNode>() else mapper.createObjectNode()
    patch.fields().forEach { (key, value) ->
        if (value.isNull) {
            result.remove(key)
        } else {
            result.set<JsonNode>(key, mergePatch(result.get(key) ?: mapper.createObjectNode(), value, mapper))
        }
    }
    return result
}

// RFC 6902 중 replace와 remove만 처리하는 최소 구현.
fun jsonPatch(target: ObjectNode, ops: JsonNode): JsonNode {
    val result = target.deepCopy()
    ops.forEach { op ->
        val field = op.get("path").asText().removePrefix("/")
        when (op.get("op").asText()) {
            "replace" -> result.set<JsonNode>(field, op.get("value"))
            "remove" -> result.remove(field)
        }
    }
    return result
}
```

프로젝트 폴더에서 `gradle run`으로 실행하면 이렇게 나옵니다.

```
[1] 평범한 DTO는 명시적 null과 필드 부재를 구분하지 못한다
  {"name":null,"age":30}  ->  name=null
  {"age":30}             ->  name=null

[2] JsonNullable은 두 경우를 isPresent로 구분한다
  {"name":null,"age":30}  ->  isPresent=true, value=null
  {"age":30}             ->  isPresent=false

[3] JSON Merge Patch(RFC 7396)에서 null은 삭제다
  대상            : {"name":"Kim","age":30,"nick":"k"}
  패치 {"nick":null}  ->  {"name":"Kim","age":30}
  패치 {"age":31}  ->  {"name":"Kim","age":31,"nick":"k"}

[4] JSON Patch(RFC 6902)는 삭제와 null 설정을 구분한다
  대상                              : {"name":"Kim","nick":"k"}
  [{"op":"replace","path":"/nick","value":null}]  ->  {"name":"Kim","nick":null}
  [{"op":"remove","path":"/nick"}]  ->  {"name":"Kim"}
```

본문에서는 이 넷을 설명 순서에 맞춰 나눠 인용했습니다. 번호는 실행 순서입니다.

## 참고

- RFC 9110 §9.3.4 PUT. [https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.4)
- RFC 5789 PATCH. [https://www.rfc-editor.org/rfc/rfc5789.html](https://www.rfc-editor.org/rfc/rfc5789.html)
- RFC 7396 JSON Merge Patch. [https://www.rfc-editor.org/rfc/rfc7396.html](https://www.rfc-editor.org/rfc/rfc7396.html)
- RFC 6902 JSON Patch. [https://www.rfc-editor.org/rfc/rfc6902.html](https://www.rfc-editor.org/rfc/rfc6902.html)
- jackson-databind #443. [https://github.com/FasterXML/jackson-databind/issues/443](https://github.com/FasterXML/jackson-databind/issues/443)
- OpenAPITools/jackson-databind-nullable. [https://github.com/OpenAPITools/jackson-databind-nullable](https://github.com/OpenAPITools/jackson-databind-nullable)
- Google AIP-134 Standard methods: Update. [https://google.aip.dev/134](https://google.aip.dev/134)
- JSON:API Updating Resources. [https://jsonapi.org/format/#crud-updating](https://jsonapi.org/format/#crud-updating)

