---
title: 'JPA에서 유니크한 관계에 유니크키를 걸었는데 Duplicate entry가 나는 이유: Hibernate flush 순서'
description: '컬렉션을 clear()로 비우고 새로 채우는 교체 패턴에 유니크키를 얹으면 Duplicate entry가 납니다. Hibernate가 삭제를 마지막에 실행하는 flush 순서를 공식 문서와 소스를 근거로 정리하고, 유니크키를 유지하면서 교체하는 방법을 다룹니다.'
pubDate: 'Jul 19 2026'
heroImage: '../../assets/jpa-orphan-removal-unique-key-hero.png'
tags: ['JPA', 'Hibernate', 'orphanRemoval', '유니크키', 'flush']
---

예전에 업무상 특정 API를 작성할 때, 1:N 관계의 테이블을 통째로 바꾸는 코드에서 `Duplicate entry` 오류가 난 적이 있습니다. 기존 목록을 지우고 새 목록을 넣는 코드인데 중복이라서 혼란스러웠습니다.

조건도 이상했습니다. 목록이 전혀 다른 값으로 바뀔 때는 통과하고, 기존 값이 하나라도 남아 있을 때만 실패했습니다. 회원의 관심분야를 **여행**과 음악에서 **여행**과 요리로 바꾸는 경우입니다. 그대로 두려던 **여행** 하나 때문에 유니크키 위반이 났습니다.

코드가 적힌 순서와 SQL이 실행되는 순서가 달랐기 때문입니다. Hibernate는 컬렉션에서 빠진 기존 행을 지우기 전에 새 엔티티의 INSERT를 먼저 실행했습니다.

> 업무 내용을 그대로 적을 수 없어서 각색하였습니다. 도메인과 테이블 이름은 실제와 다르지만 에러와 원인, 해결 과정은 겪은 그대로입니다. 환경은 Spring Boot 2.7, Hibernate 5.6 기준이고, 이 글이 다루는 flush 순서는 Hibernate 공식 문서에 명시된 동작입니다.

## 유니크해야 해서 유니크키를 넣었는데 왜 중복이 나지?

구조부터 보면 단순합니다. 회원(member)과 관심분야를 잇는 매핑 테이블(member_interest)이 있고, 회원 하나가 관심분야 하나당 행 하나를 가집니다.

![member와 member_interest의 1:N 관계를 그린 ERD. member_interest는 id(PK), member_id(FK), interest_id 세 컬럼뿐인 순수 매핑 테이블이고, member_id와 interest_id 조합에 uk_member_interest 유니크키가 걸려 있음을 표시](../../assets/jpa-member-interest-erd.svg)

여기서 한 회원이 같은 관심분야를 두 번 가질 이유는 없습니다. `(member_id=14564, interest_id=10)` 같은 행이 두 개면 그 자체로 잘못된 데이터입니다. 그래서 이 조합이 유일하도록 유니크키(unique key, UK)를 걸어 뒀습니다.

그런데 목록을 교체해 저장하는 API에서 유니크키가 위반됐다는 에러가 나기 시작했습니다. `'14564-10'`은 위반된 값의 조합(member_id 14564, interest_id 10)이고, `uk_member_interest`가 위에서 걸어 둔 그 유니크키입니다.

```text
ERROR o.h.e.jdbc.spi.SqlExceptionHelper -
Duplicate entry '14564-10' for key 'uk_member_interest'
```

중복을 막으려고 넣은 제약이 중복을 만들 리 없는 코드에서 오류를 낸 셈입니다.

문제의 코드는 목록 교체의 흔한 패턴이었습니다. 컬렉션을 비우고 받은 값으로 다시 채웁니다.

```kotlin
@OneToMany(
    fetch = FetchType.LAZY,
    mappedBy = "member",
    cascade = [CascadeType.ALL],
    orphanRemoval = true
)
val interests: MutableList<MemberInterest> = mutableListOf()

fun replaceInterests(newIds: List<Int>) {
    interests.clear()
    newIds.distinct().forEach { interests.add(MemberInterest(this, it)) }
}
```

`orphanRemoval = true`는 `remove()`나 `clear()`로 부모의 컬렉션에서 제거된 자식 엔티티의 행을 DB에서도 삭제하라는 매핑 설정입니다. 그래서 의도는 명확합니다. `clear()`로 기존 행이 전부 삭제되고, `add()`로 새 행이 삽입됩니다.

테스트가 이 버그를 놓친 이유도 실패 조건에 있습니다. 목록을 매번 전혀 다른 값으로 바꾸는 테스트만 있으면 전부 통과합니다.

## Hibernate는 PK로만 엔티티를 식별하기 때문에

"같은 값이면 그대로 두면 되지 않나"가 자연스러운 기대인데, Hibernate는 그렇게 하지 않습니다. 엔티티를 기본키(PK)로만 식별하기 때문입니다.

- `clear()`로 컬렉션에서 제거된 기존 자식: PK가 있는 엔티티. 삭제 대상
- `add()`로 들어온 새 자식: PK가 null인 엔티티. 삽입 대상

두 엔티티의 `(member_id, interest_id)` 값이 같다는 것은 유니크키를 아는 DB의 사정이고, Hibernate는 비즈니스 값을 추적하지 않습니다. PK가 다르면(또는 아직 없으면) 서로 무관한 엔티티입니다. 그래서 같은 값이 유지되는 경우에도 "기존 행 삭제 + 새 행 삽입" 두 작업이 예약됩니다.

여기까지는 문제가 아닙니다. 삭제가 먼저 실행되면 삽입은 성공합니다. 문제는 실행 순서입니다.

## Hibernate에서 SQL은 코드 순서가 아니라 ActionQueue 순서로 실행됨

flush는 영속성 컨텍스트에 쌓인 변경을 SQL로 만들어 DB에 내보내는 동작입니다. 이때 Hibernate는 예약된 작업들을 ActionQueue라는 내부 큐에 모았다가 고정된 순서로 실행합니다. 공식 문서가 명시한 순서는 다음과 같습니다.

1. `OrphanRemovalAction`: 연관이 끊긴 엔티티 삭제
2. `EntityInsertAction` 또는 `EntityIdentityInsertAction`: 엔티티 삽입
3. `EntityUpdateAction`: 엔티티 갱신
4. `QueuedOperationCollectionAction`: 컬렉션 예약 작업
5. `CollectionRemoveAction`: 컬렉션 삭제
6. `CollectionUpdateAction`: 컬렉션 갱신
7. `CollectionRecreateAction`: 컬렉션 재생성
8. `EntityDeleteAction`: 엔티티 삭제

삽입이 2순위, 엔티티 삭제가 8순위로 맨 마지막입니다. [문서상으로는](https://docs.jboss.org/hibernate/orm/5.6/userguide/html_single/Hibernate_User_Guide.html#flushing) 이 순서가 코드 작성 순서와 무관하다고 합니다. 엔티티를 먼저 `remove()`하고 새 엔티티를 `persist()`해도, 실행은 INSERT가 먼저이고 DELETE가 나중입니다.

`clear()`와 `add()` 자체는 SQL을 만들지 않습니다. 컬렉션 객체를 메모리에서 바꿀 뿐이고, 어떤 SQL이 나갈지는 flush 시점에 정해집니다. 기존 목록이 `[10, 20]`이고 새 목록이 `[10, 30]`인 경우로 따라가 보겠습니다.

`interests.clear()`가 실행되면 컬렉션이 먼저 초기화됩니다. 무엇을 지울지 정하려면 어떤 행이 있었는지 알아야 하므로 SELECT가 한 번 나갑니다. 로드된 `id=1, (14564, 10)`과 `id=2, (14564, 20)`이 컬렉션에서 빠지고, `orphanRemoval = true`에 따라 삭제 대상으로 예약됩니다.

이어서 `add()`가 `interest_id`가 10인 새 객체와 30인 새 객체를 담습니다. 둘 다 PK가 없는 새 객체이므로 삽입 대상으로 예약됩니다. 값이 유지되는 10도 여기서 삭제 1건과 삽입 1건으로 갈라집니다.

flush 시점에는 삽입 예약 두 건과 삭제 예약 두 건이 ActionQueue 순서대로 실행됩니다.

```text
① INSERT (member_id=14564, interest_id=10)   ← 새 엔티티
     DB에는 기존 (14564, 10) 행이 아직 살아 있음
     유니크키 위반 → Duplicate entry          ← 여기서 예외
② DELETE는 실행되지 못함
```

지우고 넣는 코드가 실제로는 넣으려다 기존 행에 막혀 실패합니다. 최종 상태만 보면 `(14564, 10)`은 한 행만 남는 것이 맞습니다. 그러나 DB는 구문(statement) 하나가 끝날 때마다 제약을 검사하므로, INSERT가 실행되는 순간의 겹침을 허용하지 않습니다.

## clear()의 삭제는 마지막 순서로 실행됨

그런데 이상합니다. `replaceInterests()` 함수 내에서 `clear()`를 호출하면 엔티티의 관계는 사라질 텐데 `OrphanRemovalAction`이 먼저 실행되지 않는 걸까요?

답은 실제 Hibernate 5.6 소스를 보면 나옵니다. 두 액션은 Hibernate가 상황을 보고 고르는 것이 아니라, **어느 메서드를 거쳐 삭제가 예약됐는지**로 정해집니다.

- 세션의 `delete()`를 거치면 8순위 `EntityDeleteAction`
- 세션의 `removeOrphanBeforeUpdates()`를 거치면 1순위 `OrphanRemovalAction`

갈림길은 삭제 이벤트를 처리하는 `DefaultDeleteEventListener`의 `if`와 `else` 한 쌍입니다.

```java
// DefaultDeleteEventListener.java:286~313 (hibernate-core 5.6.15.Final)

286  if ( isOrphanRemovalBeforeUpdates ) {      // 참일 때만 1순위 액션
289      session.getActionQueue().addAction(
290              new OrphanRemovalAction( ... ) // 290~298행. 생성자 인자는 인용에서 생략
299      );
300  }
301  else {                                     // 그 밖의 모든 삭제는 8순위 액션
303      session.getActionQueue().addAction(
304              new EntityDeleteAction( ... )  // 304~312행. 생성자 인자는 인용에서 생략
312      );
313  }
```

`isOrphanRemovalBeforeUpdates`가 참이 되는 것은 `removeOrphanBeforeUpdates()`를 거쳐 들어온 삭제뿐입니다. 세션의 `delete()`로 들어온 삭제는 `else`로 갑니다. 소스 전체에서 두 액션을 만드는 곳은 이 두 줄뿐입니다.

그러면 컬렉션에서 빠진 자식이 둘 중 어느 쪽으로 가는지 보면 됩니다. 그 처리를 맡은 `Cascade.deleteOrphans()`에는 `delete()` 호출 하나만 있습니다. 아래 코드의 `eventSource`는 세션을 가리킵니다. Hibernate가 세션을 이벤트 발생자로 다룰 때 쓰는 인터페이스이고, 실제 구현이 `SessionImpl`입니다.

```java
// Cascade.java:587~609 (hibernate-core 5.6.15.Final)

587  /**
588   * Delete any entities that were removed from the collection
589   */
590  private static void deleteOrphans(EventSource eventSource, String entityName, PersistentCollection pc) {
591      ...   // 591~601행. 스냅샷과 현재 컬렉션을 비교해 orphans를 구하는 코드. 인용에서 생략
603      for ( Object orphan : orphans ) {          // 컬렉션에서 빠진 자식들
604          if ( orphan != null ) {
605              LOG.tracev( "Deleting orphaned entity instance: {0}", entityName );
606              eventSource.delete( entityName, orphan, false, new HashSet() );  // 일반 삭제 이벤트
607          }
608      }
609  }
```

`removeOrphanBeforeUpdates()`를 호출하는 코드가 이 메서드에는 없습니다. 조건에 따라 갈라질 여지 없이 모든 자식이 `delete()`로 갑니다. `delete()`는 `em.remove()`를 직접 호출한 것과 같은 일반 삭제 이벤트이므로, 결과는 8순위 `EntityDeleteAction`입니다.

`removeOrphanBeforeUpdates()`를 호출하는 코드는 일대일 연관을 처리하는 다른 메서드에만 있습니다. 그 메서드는 첫 줄에서 일대일 연관인지부터 확인하므로 컬렉션은 도달하지 않습니다. 소스 전체를 검색해도 1순위 액션을 만드는 경로는 그 하나뿐입니다. 검색 결과는 부록에 정리했습니다.

그래서 `clear()`로 빠진 자식은 1순위가 아니라 8순위로 예약됩니다. 5순위 `CollectionRemoveAction`도 아닙니다. 그 액션은 컬렉션 자체를 비우는 작업인데, 이 연관은 `mappedBy`로 걸린 역방향이라 컬렉션이 자체 SQL을 내지 않습니다. 행의 삭제는 전부 자식 엔티티 단위 작업으로 나갑니다.

정리하면 `orphanRemoval = true`는 "컬렉션에서 제거된 자식을 삭제하라"는 정책일 뿐, 언제 삭제할지까지 정하지 않습니다. `clear()`로 비운 컬렉션의 삭제는 맨 마지막 순서입니다.

## 삽입이 먼저 실행돼도 대부분은 문제가 없음

공식 문서는 이 순서를 명시할 뿐, 왜 이렇게 정했는지는 설명하지 않습니다. 다만 새 부모와 자식을 만들고 옛것을 지우는 일반적인 시나리오에서는 이 순서가 외래키(FK) 제약을 지키는 데 유리합니다.

```text
INSERT 새 부모   (자식이 참조할 행을 먼저 확보)
INSERT 새 자식   (방금 만든 부모를 FK로 참조)
DELETE 옛 자식   (FK로 묶인 자식부터 정리)
DELETE 옛 부모
```

대부분의 경우 삽입되는 행과 삭제되는 행은 PK가 달라 충돌할 일이 없습니다. 이번 경우가 예외였던 이유는 같은 테이블에서 삽입될 행과 삭제될 행의 중복 체크가 유니크키 값을 통해 이뤄졌기 때문입니다. 같은 순서 문제가 2007년에 이슈로 등록됐지만(HHH-2801 "wrong insert/delete order when updating record-set") Rejected로 닫혔습니다. Hibernate 입장에서 이 순서는 의도된 동작입니다.

## 유지할 행까지 지웠다 다시 넣는 것이 문제임

목록을 통째로 받아 통째로 바꾸는 API 자체는 문제가 없고, 유니크키도 마찬가지입니다. 실패하는 조합은 더 좁습니다. 유지해야 할 행까지 삭제 대상으로 만들어 놓고, 같은 유니크키 값을 가진 새 엔티티를 같은 flush 안에서 삽입하는 방식입니다.

그래서 이 셋 중 하나만 바꿔도 오류는 사라집니다.

- 유지되는 행을 삭제 대상에서 빼면 충돌할 SQL 자체가 생기지 않습니다
- `clear()` 직후 `flush()`를 호출해 삭제를 먼저 내보내면 통과합니다. 다만 유지할 행까지 지웠다 다시 만드는 것은 그대로입니다
- 유니크키를 제거하면 통과합니다. 대신 중복을 막던 제약이 사라집니다

당장 문제가 있었을 땐 유니크키만 제거했습니다. 제약을 빼면 에러는 사라지지만 원인은 그대로 남습니다.

## 유지할 행은 지우지 말고 변경된 것만 지우고 추가해야 함

유니크키를 유지하면서 교체하려면, 전체를 지우고 다시 넣는 대신 없어진 것만 지우고 새로 생긴 것만 추가해야 합니다. 유지되는 행은 건드리지 않으므로 같은 값의 재삽입이 없고, 충돌도 없습니다.

```kotlin
fun replaceInterests(newIds: List<Int>) {
    val target = newIds.toSet()
    val current = interests.map { it.interestId }.toSet()

    interests.removeIf { it.interestId !in target }   // 빠진 것만 삭제
    target.filter { it !in current }
          .forEach { interests.add(MemberInterest(this, it)) }  // 새로운 것만 삽입
}
```

다른 선택지와 함께 별도 프로젝트에서 전부 실행해 봤습니다. 조건은 모두 같습니다. 기존 목록이 `[1, 2]`이고 새 목록이 `[2, 3]`이라 값 2가 유지됩니다.

| 방법 | 유니크키 | 결과 | 실행된 SQL |
| --- | --- | --- | --- |
| `clear()` 후 `add()` (문제의 코드) | 유지 | 실패 | INSERT에서 위반, DELETE 0건 |
| 빠진 것만 삭제하고 새 것만 삽입 (위 코드) | 유지 | 성공 | INSERT 1건, DELETE 1건 |
| `clear()` 후 강제 `flush()` | 유지 | 성공 | DELETE 2건 후 INSERT 2건 |
| 유니크키 제거 | 포기 | 성공 | INSERT 2건 후 DELETE 2건 |
| 네이티브 DELETE 후 INSERT | 유지 | 실패 | `StaleStateException` |

**환경**: Hibernate 5.6.15, H2 2.1.214, `show_sql=true`

문제의 코드는 로그에 `DELETE`가 한 줄도 없습니다. 삽입에서 막혀 삭제까지 도달하지 못했다는 앞의 설명이 그대로 나타납니다.

강제 `flush()`는 통과합니다. 다만 유지할 행까지 지웠다 다시 만드는 것은 그대로이고, 트랜잭션 중간에 flush를 끼워 넣어야 합니다.

네이티브 DELETE는 영속성 컨텍스트가 알지 못합니다. 네이티브 쿼리로 두 행을 지운 뒤에도 컬렉션에는 두 건이 남아 있었고, Hibernate가 이미 없는 행을 다시 지우려다 실패했습니다.

```text
delete from MemberInterest where member_id = 4   ← 네이티브 쿼리, 2행 삭제
영속성 컨텍스트의 컬렉션 크기: 2
insert into MemberInterest ...
delete from MemberInterest where id=?
StaleStateException: actual row count: 0; expected: 1
```

유니크키를 제거하면 오류는 사라집니다. 다만 로그를 보면 `INSERT` 두 건이 `DELETE` 두 건보다 먼저 실행됩니다. 트랜잭션 중간에 `(member_id, 2)` 행이 두 개 존재하는 순간이 실재하고, 최종 상태만 정상입니다. 애플리케이션 코드로 중복을 막는 데도 한계가 있습니다. `distinct()`가 막는 것은 한 요청 안에서 전달된 목록의 중복뿐입니다. 같은 회원을 고치는 요청이 동시에 들어오거나, 배치나 관리자 기능처럼 다른 저장 경로가 나중에 추가되면 막지 못합니다. 쓰기 메서드가 하나라는 것은 호출 경로가 하나라는 뜻이지, 한 번에 하나씩 실행된다는 뜻이 아닙니다.

이 조합의 중복이 잘못된 데이터라면, 애플리케이션 코드에 버그가 있어도 DB가 중복을 거부하게 두는 편이 낫습니다. 유니크키 제거는 중복이 실제로 문제가 되지 않거나, 동시 쓰기까지 포함해 다른 방법으로 정합성을 보장할 수 있을 때만 검토할 일입니다.

## 정리

- 목록 교체 API가 같은 값이 유지될 때만 `Duplicate entry`로 실패한다면, Hibernate의 flush 순서를 의심한다
- Hibernate는 엔티티를 PK로만 식별한다. 값이 같아도 `clear()` + `add()`는 "기존 행 삭제 + 새 행 삽입"이 된다
- SQL은 코드 순서가 아니라 ActionQueue의 고정 순서로 실행된다. 삽입이 2순위, 엔티티 삭제가 8순위다
- `clear()`로 연관이 끊긴 엔티티의 삭제는 1순위 `OrphanRemovalAction`이 아니라 8순위 `EntityDeleteAction`으로 간다
- 이 순서는 일반적인 연관관계 변경에서는 유리하다. 같은 테이블 안에서 삭제될 행과 삽입될 행이 유니크키 값을 공유할 때만 문제가 된다
- 중복이 허용되지 않는 관계라면 유니크키를 유지하고, 유지할 행은 건드리지 않은 채 변경된 것만 지우고 추가한다. 유니크키 제거는 동시 쓰기까지 막을 다른 방법이 있을 때만 검토한다

## 부록: 1순위 경로가 일대일 연관 전용이라는 근거

본문에서 본 `isOrphanRemovalBeforeUpdates`가 참이 되는 경로는 하나뿐입니다. `SessionImpl.removeOrphanBeforeUpdates()`가 `DeleteEvent`를 만들면서 해당 인자에 `true`를 넘기는 경우입니다.

```java
// SessionImpl.java:906~924 (hibernate-core 5.6.15.Final)

906  public void removeOrphanBeforeUpdates(String entityName, Object child) {
907      // TODO: The removeOrphan concept is a temporary "hack" for HHH-6484.
908      // This should be removed once action/task ordering is improved.
909      ...   // 909~915행. 로깅과 카운터 처리. 인용에서 생략
916      fireDelete( new DeleteEvent( entityName, child, false, true, this ) );  // 네 번째 인자가 orphanRemovalBeforeUpdates
917      ...   // 917~923행. finally 블록. 인용에서 생략
924  }
```

이 메서드를 호출하는 곳은 `Cascade`의 일대일 연관 분기 한 줄뿐입니다. 나머지 검색 결과는 인터페이스 선언과 위임 구현입니다.

```text
Cascade.java:355                      eventSource.removeOrphanBeforeUpdates( ... )   ← 유일한 호출
SessionImpl.java:906                  구현
EventSource.java:66                   인터페이스 선언
SessionImplementor.java:174           인터페이스 선언
SessionDelegatorBaseImpl.java:1204    위임
```

주석에 적힌 HHH-6484는 일대일 연관에서 자식을 새 인스턴스로 교체하면 옛 자식이 삭제되지 않아 제약 위반이 나던 이슈입니다. 이 글의 사고와 같은 종류인데, 우회로가 일대일 연관만 대상으로 좁게 만들어졌습니다. 주석은 작업 순서 체계가 개선되면 이 코드가 없어져야 한다고 밝히고 있습니다.

## 부록: 식별 관계로 모델링했다면 어땠을까?

식별용으로만 둔 id 컬럼(대리키)을 없애고 `(member_id, interest_id)`를 그대로 복합 PK로 쓰는 모델링(식별 관계)이었다면, 이 조합의 유일성은 PK가 보장하므로 유니크키를 따로 걸 일이 없습니다. 순수 매핑 테이블에서는 이쪽이 정석 모델링이기도 합니다.

그래도 `clear()` 후 `add()`는 실패합니다. 복합 PK로 모델링한 엔티티를 만들어 같은 코드를 돌려 보니, 이번에는 DB가 아니라 Hibernate 단계에서 막혔습니다.

```text
EntityExistsException: A different object with the same identifier value
was already associated with the session : [repro.CMemberInterest#...]
```

SQL이 한 줄도 나가기 전입니다. 기존 엔티티가 삭제 대기 상태로 영속성 컨텍스트에 남아 있는데 같은 PK 값을 가진 새 엔티티를 추가했기 때문입니다. 식별 관계는 유니크키의 자리를 PK로 옮길 뿐이고, "유지할 행을 지웠다 다시 만든다"는 원인은 그대로 남습니다.

## 참고 문헌

- [Hibernate ORM 5.6 User Guide, Flushing](https://docs.jboss.org/hibernate/orm/5.6/userguide/html_single/Hibernate_User_Guide.html#flushing): 6.5 Flush operation order. ActionQueue의 8단계 실행 순서 목록과, remove를 먼저 호출해도 DELETE가 INSERT 뒤에 실행된다는 공식 예제.
- [A beginner's guide to Hibernate flush operation order](https://vladmihalcea.com/hibernate-facts-knowing-flush-operations-order-matters/): 같은 유니크키 값을 가진 엔티티를 삭제 후 재생성할 때 제약 위반이 나는 재현 예제. 삭제 후 재삽입 대신 기존 엔티티를 갱신하라는 권장.
- [How does orphanRemoval work with JPA and Hibernate](https://vladmihalcea.com/orphanremoval-jpa-hibernate/): orphanRemoval의 동작 정의.
- [HHH-2801](https://hibernate.atlassian.net/browse/HHH-2801): "wrong insert/delete order when updating record-set". 2007년 등록, Rejected로 종료. 이 순서가 의도된 동작이라는 근거.
- [Hibernate 5.6 소스, Cascade.java](https://github.com/hibernate/hibernate-orm/blob/5.6/hibernate-core/src/main/java/org/hibernate/engine/internal/Cascade.java): `deleteOrphans()`가 컬렉션에서 제거되어 연관이 끊긴 엔티티를 일반 삭제 이벤트로 처리하는 부분.
- [Hibernate 5.6 소스, SessionImpl.java](https://github.com/hibernate/hibernate-orm/blob/5.6/hibernate-core/src/main/java/org/hibernate/internal/SessionImpl.java): `removeOrphanBeforeUpdates()`와 HHH-6484 임시 조치라는 주석.
