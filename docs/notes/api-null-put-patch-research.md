# 리서치 노트: API에서 null은 무엇을 의미하는가 (PUT vs PATCH, null vs 필드 누락)

블로그 글 "API에서 null은 무엇을 의미하는가"의 사전 리서치. 1차 출처(RFC, 공식 설계 가이드) 기준으로 정리한다. 회사 식별자는 제외한다.

## 핵심 질문과 결론

- 요청 본문에서 **필드에 null을 넣어 보내는 것**과 **필드를 아예 빼는 것**은 같지 않다.
- "null = 그 필드를 지워라, 누락 = 그대로 둬라"는 규칙은 임의 관행이 아니라 **JSON Merge Patch(RFC 7396/7386)**가 정의한 규약이다.
- 값을 **명시적으로 null로 설정**하려면 Merge Patch로는 안 되고, **JSON Patch(RFC 6902)**의 연산이나 **field mask**가 필요하다.
- 전체 교체는 **PUT**, 일부 교체는 **PATCH**. PUT은 전체 상태 교체라 뺀 필드가 제거로 해석될 수 있다.

## 1. 3-상태 문제 (값 / 명시적 null / 누락)

JSON 필드는 세 상태를 가진다.

1. 값이 있음 → 그 값으로 설정
2. `null`로 있음 → 규약에 따라 "삭제" 또는 "null로 설정"
3. 필드가 아예 없음 → 보통 "변경하지 않음"

표준 JSON은 (2)와 (3)을 언어 차원에서 구분하지 못한다(nullable은 값/null 두 상태만). 그래서 API는 이 셋의 해석 규약을 **따로 정하고 문서화**해야 한다. 대표 규약이 JSON Merge Patch다.

## 2. HTTP 메서드: PUT vs PATCH

### PUT — 전체 교체, 멱등
- 정의(RFC 9110 §9.3.4): 대상 리소스의 상태를 요청 표현으로 "created or replaced"한다. 즉 본문이 리소스의 새 전체 상태다.
- 성공한 PUT 뒤의 GET은 동등한 표현을 돌려준다고 서술 → **전체 교체**의 근거. 본문에서 뺀 필드는 이후 표현에 남지 않는다고 해석될 수 있다.
- 멱등(RFC 9110 §9.2.2: "PUT, DELETE, and safe request methods are idempotent").
- 주의: 스펙이 "생략된 필드는 무조건 제거"라고 필드 단위로 못박지는 않는다. 서버가 표현을 전체 상태로 해석할 때 따라오는 귀결이다.
- URL: https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.4 , https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.2

### PATCH — 부분 수정, 비멱등, 원자적
- 정의(RFC 5789 §2): 본문은 리소스 전체가 아니라 "how a resource ... should be modified"를 기술하는 지시서(patch document)다.
- "PATCH is neither safe nor idempotent."
- 원자성: "The server MUST apply the entire set of changes atomically" / 전부 적용 못 하면 "MUST NOT apply any of the changes."
- 동시 수정 충돌 회피로 조건부 요청(`If-Match` + 강한 ETag) 권고. 미지원 형식은 415, `Accept-Patch`로 지원 형식 광고.
- URL: https://www.rfc-editor.org/rfc/rfc5789.html#section-2

## 3. PATCH 본문 형식 세 갈래 (여기서 null의 의미가 갈린다)

### (a) JSON Merge Patch — RFC 7386/7396 ★핵심
- 규칙: 멤버 값이 `null`이면 대상에서 그 멤버를 **제거**, 패치에 없는 멤버는 **그대로 둠**.
- 원문: "Null values in the merge patch are given special meaning to indicate the removal of existing values in the target."
- 예: 대상 `{"a":"b","c":{"d":"e","f":"g"}}` + 패치 `{"a":"z","c":{"f":null}}` → `{"a":"z","c":{"d":"e"}}` (a 교체, f 제거, d 유지).
- 한계: null이 "삭제" 전용이라 **값을 진짜 null로 설정할 수 없다**. "not suitable for ... explicit null values."
- 미디어 타입: `application/merge-patch+json`.
- URL: https://www.rfc-editor.org/rfc/rfc7386.html

### (b) JSON Patch — RFC 6902
- 본문이 `add`/`remove`/`replace`/`move`/`copy`/`test` **연산 객체의 배열**.
- `replace`/`add`의 `value`에 `null`을 넣어 **값을 명시적으로 null로 설정** 가능. 제거는 별도 `remove` 연산. 그래서 "삭제"와 "null 설정"을 구분한다.
- 미디어 타입: `application/json-patch+json`.
- URL: https://www.rfc-editor.org/rfc/rfc6902.html

### (c) Field mask — Google AIP
- `update_mask`(google.protobuf.FieldMask)로 "어떤 필드를 바꿀지"를 요청이 명시 → null/누락 해석에 의존하지 않는다.
- 마스크에 있으면 본문 값으로 덮어쓰고(비어 있으면 clear), 없으면 건드리지 않는다. `*`는 전체 교체(PUT과 동일 의미).
- 부분 수정 지원 시 마스크는 필수. PUT 대신 PATCH를 표준으로 삼는 이유는 새 필드 추가 시 PUT이 하위호환을 깨기 때문.
- URL: https://google.aip.dev/134 , https://google.aip.dev/161

## 4. 코드 레벨 3-상태 함정 (Jackson 중심)

- 표준 POJO는 "명시적 null로 옴"과 "필드가 안 옴"이 **둘 다 필드값 null**로 역직렬화돼 구분 불가.
- 구분 못 하면 PATCH가 안 보낸 필드까지 null로 덮어써 **의도치 않게 필드를 지우는 버그**가 난다.
- 해결: `JsonNullable`(OpenAPITools/jackson-databind-nullable) 래퍼로 감싸 `isPresent()`로 도착 여부 판별. 부재는 `JsonNullable.undefined()`.
- `Optional`은 부재와 null 둘 다 `empty`가 돼 구분 불가라 부적합(게다가 필드용 설계가 아님).
- `@JsonInclude`는 직렬화(출력) 제어라 역직렬화 3-상태 구분과는 별개 문제.
- JS/TS는 `undefined`(부재)와 `null`(명시)로 비교적 자연스럽게 3-상태 표현 가능.
- URL: https://github.com/OpenAPITools/jackson-databind-nullable

## 5. 설계 가이드 입장 요약

- **Google AIP**: field mask로 모호성 자체를 제거. PATCH 표준.
- **Microsoft/Azure**: Merge Patch에서 null=삭제로 받되, "도메인에 유효한 null이 있으면 Merge Patch 부적합, JSON Patch를 써라"고 경고.
- **JSON:API**: 누락 속성을 null로 해석하면 안 되고 "현재값 유지"로 해석해야 한다("MUST NOT interpret missing attributes as null").
- **Stripe**: form 파라미터에서 빈 문자열을 unset 신호로 사용. 언어별 SDK가 null/None을 제각각 처리해 삭제가 안 되는 버그가 반복됨 → 3-상태 문제가 클라이언트 직렬화 층에서도 터진다.
- URL: https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design , https://jsonapi.org/format/#crud-updating , https://docs.stripe.com/metadata

## 6. 최종 결론 (블로그 thesis)

1. "null을 보내면 지워진다"는 규칙의 출처는 JSON Merge Patch다. 규약을 안 정하면 null과 누락의 의미가 서버마다 다르다.
2. Merge Patch로는 값을 null로 설정할 수 없다. 그게 필요하면 JSON Patch나 field mask.
3. PUT은 전체 교체(뺀 필드는 제거로 해석 가능), PATCH는 부분 수정. 부분만 바꾸려면 PATCH.
4. 서버 코드가 3-상태를 실제로 구분(JsonNullable 등)하지 못하면 규약이 무의미해지고, PATCH가 필드를 지우는 버그가 난다.

## 제안 글 구조 (초안)

1. 도입: 같은 수정 요청인데 필드가 사라지는 사고 (3-상태 문제 제기)
2. null / 명시적 null / 누락 세 상태와, JSON이 뒤 둘을 못 가리는 한계
3. PUT vs PATCH: 전체 교체와 부분 수정, 멱등성
4. PATCH의 본문 형식: Merge Patch(null=삭제) vs JSON Patch(null 설정 가능) vs field mask
5. "null을 보낼까 필드를 뺄까"의 답: 어느 규약을 쓰느냐에 달렸다
6. 서버 코드의 함정: Jackson에서 null과 부재를 구분하기 (JsonNullable)
7. 결론: PUT은 전체 교체, PATCH는 부분 교체. 규약을 정하고 코드로 강제하라

## 미확인/주의

- RFC 9110 PUT의 "entire state" 강조 표현과 RFC 5789 §2.2 상태코드(415/422/409) 세부 문장은 원문 재대조 권장(직접 인용 시).
- JS/TS undefined 관행은 널리 쓰이나 규정한 1차 문서는 미확인.
