---
title: 'Spring Boot 3 전환 뒤 QueryDSL 하위 쿼리가 500을 낸 이유: JPQLTemplates와 Hibernate 6'
description: 'Spring Boot 3로 올린 뒤 테스트를 통과한 QueryDSL 쿼리가 앱에서만 실패했습니다. JPAQueryFactory가 고르는 두 템플릿(자동 감지와 JPQLTemplates.DEFAULT)이 Hibernate 6에서 각각 어떤 패턴을 깨는지 QueryDSL 소스를 근거로 정리하고, 앱과 테스트의 템플릿을 맞춘 과정을 다룹니다.'
pubDate: 'Oct 17 2026'
tags: ['QueryDSL', 'Hibernate', 'JPA', 'Spring Boot', '테스트', '웹개발']
category: 'backend'
draft: false
---

예전에 업무상 맡은 서비스를 Spring Boot 3로 올린 적이 있습니다. 전환이 끝나고 회귀 테스트를 하던 QA에서, 검색 API 하나가 500을 낸다는 보고가 왔습니다. 그 API의 쿼리는 전환 전과 한 글자도 다르지 않았습니다. 그 쿼리를 검증하는 테스트도 통과하고 있었습니다.

로그에는 Hibernate 6의 JPQL 파서가 낸 `SyntaxException`이 남아 있었습니다. 문제가 된 JPQL에는 `exists (select  from ...)`처럼 select 목록이 비어 있었습니다. 같은 QueryDSL 코드가 테스트에서는 올바른 JPQL이 됐습니다. 앱에서는 select 목록이 빈 JPQL이 됐습니다.

원인은 앱과 테스트가 서로 다른 템플릿으로 `JPAQueryFactory`를 만들고 있었다는 데 있었습니다.

> 업무 내용을 그대로 적을 수 없어서 각색하였습니다. 엔티티와 쿼리는 실제와 다르지만 오류와 원인, 해결 과정은 겪은 그대로입니다. 환경은 QueryDSL 5.0.0(jakarta), Hibernate 6.4.4, Spring Boot 3.2.5 기준이고, 템플릿 동작은 QueryDSL 5.0.0 소스로 확인했습니다.

## QueryDSL 템플릿이란?

QueryDSL 템플릿은 QueryDSL 식을 JPQL 문자열로 바꾸는 규칙입니다. QueryDSL 코드는 DB로 바로 가지 않습니다. QueryDSL이 먼저 JPQL 문자열을 만들고, Hibernate가 그 문자열을 파싱해 SQL로 바꿉니다.

```text
Kotlin QueryDSL 코드
  → JPQLSerializer (JPQLTemplates의 규칙을 따름)
  → JPQL 문자열
  → Hibernate 6 파서 (문법 검사)
  → SQL
  → DB
```

`JPQLTemplates`는 이 중 두 가지를 정합니다.

- QueryDSL 식을 어떤 JPQL 문자열로 쓸지
- 쿼리 결과를 어떤 API로 가져올지(QueryHandler)

같은 QueryDSL 코드라도 템플릿이 다르면 다른 JPQL 문자열이 나옵니다. Hibernate 6의 파서는 그 문자열의 문법을 검사합니다. 템플릿이 만든 문자열이 문법에 어긋나면 쿼리는 실행 전에 실패합니다.

## 템플릿을 고르는 두 경로: 자동 감지와 JPQLTemplates.DEFAULT

`JPAQueryFactory`를 만들 때 템플릿을 넘기느냐에 따라 템플릿이 갈립니다.

```kotlin
// 템플릿을 넘기지 않음: 자동 감지
val autoDetected = JPAQueryFactory(entityManager)

// 템플릿을 넘김: JPA 표준 템플릿
val jpaDefault = JPAQueryFactory(JPQLTemplates.DEFAULT, entityManager)
```

템플릿을 넘기지 않으면 QueryDSL의 `JPAProvider`가 `EntityManager`의 구현체를 보고 템플릿을 고릅니다. Hibernate의 `Session`이면 `Hibernate5Templates`가 선택됩니다. Hibernate 6에서도 클래스 이름이 같아 같은 템플릿이 선택됩니다.

| 생성 방식 | 선택되는 템플릿 | 결과를 가져오는 QueryHandler |
|---|---|---|
| `JPAQueryFactory(em)` | `Hibernate5Templates` | `HibernateHandler`. Hibernate 5의 API를 씀 |
| `JPAQueryFactory(JPQLTemplates.DEFAULT, em)` | `JPQLTemplates.DEFAULT` | `DefaultQueryHandler`. JPA 표준 API만 씀 |

`Hibernate5Templates`는 `HQLTemplates`를 상속합니다. `HQLTemplates`는 클래스 경로에 `HibernateHandler`가 있으면 그것을 QueryHandler로 씁니다. 두 템플릿은 문자열 규칙도 다릅니다. CASE 식 안의 상수를 리터럴로 쓸지 정하는 `isCaseWithLiterals()`가 `JPQLTemplates`에서는 `false`, `HQLTemplates`에서는 `true`를 반환합니다.

Hibernate 5.6과 6.4 환경을 각각 구성하고, 두 템플릿으로 같은 쿼리를 실행해 차이를 확인했습니다. Hibernate 6에서 문제가 된 패턴은 세 가지였습니다.

## 두 템플릿의 차이 1: select 목록이 빈 하위 쿼리

존재 여부만 확인하는 하위 쿼리는 select 목록이 필요 없습니다. 그래서 `JPAExpressions.select()`를 인자 없이 호출하는 코드가 있었습니다. 재고가 남은 상품만 찾는 쿼리로 바꿔 적었습니다.

```kotlin
queryFactory
    .selectFrom(product)
    .where(
        JPAExpressions.select()
            .from(stock)
            .where(stock.product.eq(product), stock.quantity.gt(0))
            .exists()
    )
    .fetch()
```

자동 감지 템플릿에서는 이 코드가 유효한 JPQL로 바뀌어 실행됩니다. `JPQLTemplates.DEFAULT`에서는 select 목록이 빈 채로 나갑니다.

```text
select product from Product product
where exists (select  from Stock stock where stock.product = product and stock.quantity > ?1)
```

Hibernate 6의 파서는 이 문자열을 받지 않고 `SyntaxException`을 던집니다. 이 예외가 API까지 올라와 500이 됐습니다.

## 두 템플릿의 차이 2: CaseBuilder 상수 합계

조건에 맞는 행의 개수를 세려고 CASE 식에 1과 0을 넣어 합하는 코드가 있었습니다.

```kotlin
val inStockCount = CaseBuilder()
    .`when`(stock.quantity.gt(0)).then(1)
    .otherwise(0)
    .sum()
```

자동 감지 템플릿은 `isCaseWithLiterals()`가 `true`라서 1과 0을 리터럴로 씁니다. 이 쿼리는 정상으로 실행됩니다.

`JPQLTemplates.DEFAULT`는 1과 0을 바인드 파라미터로 바꿉니다. JPQL은 `sum(case when ... then ? else ? end)` 모양이 됩니다. Hibernate 6은 `sum`의 반환 타입을 인자의 타입에서 정합니다. 이 식은 인자가 전부 바인드 파라미터라서 타입을 정하지 못합니다. 그 결과 `SumReturnTypeResolver`에서 `NullPointerException`이 났습니다.

이 실패는 Hibernate 6에서만 나는 것이 아닙니다. Hibernate 5.6 환경에서도 `JPQLTemplates.DEFAULT`로 만들면 같은 쿼리가 NPE로 실패했습니다. Hibernate 버전보다 템플릿이 원인입니다.

## 두 템플릿의 차이 3: GroupBy.transform

세 번째는 반대로 자동 감지 템플릿에서만 실패합니다. `GroupBy.transform`은 결과를 한 행씩 읽으며 묶습니다. 자동 감지 템플릿의 `HibernateHandler`는 이때 Hibernate의 `ScrollableResults`를 열고, 행마다 `ScrollableResults.get(int)`를 호출합니다.

Hibernate 6.4의 `ScrollableResults`에는 인자 없는 `get()`만 있고 `get(int)`가 없습니다. QueryDSL 5.0.0은 Hibernate 5에 맞춰 컴파일됐으므로 컴파일 오류는 나지 않습니다. 대신 실행 중에 `NoSuchMethodError`가 납니다. `JPQLTemplates.DEFAULT`의 `DefaultQueryHandler`는 JPA 표준인 `getResultList()`로 결과를 가져오므로 이 오류가 나지 않습니다.

세 차이를 표로 모았습니다.

| QueryDSL 코드 | 자동 감지 (`Hibernate5Templates`) | `JPQLTemplates.DEFAULT` |
|---|---|---|
| select 목록이 빈 하위 쿼리 | 정상 | `SyntaxException` |
| `CaseBuilder` 상수 합계 | 정상 | `SumReturnTypeResolver`에서 NPE |
| `GroupBy.transform` | `NoSuchMethodError` | 정상 |

어느 템플릿도 Hibernate 6에서 세 패턴을 모두 받지 못합니다. 템플릿마다 실패하는 패턴이 다릅니다.

## 왜 테스트로 오류를 발견하지 못했을까?

Spring Boot 3 전환 작업에서 앱이 쓰는 `JPAQueryFactory` 빈은 `JPQLTemplates.DEFAULT`로 바뀌었습니다. 차이 3의 `transform` 오류를 피하려는 변경이었습니다. 테스트는 그렇지 않았습니다. 테스트 126곳이 빈을 주입받지 않고 `JPAQueryFactory`를 직접 만들고 있었고, 템플릿 인자가 없었습니다.

```kotlin
// 앱이 쓰는 빈
@Bean
fun jpaQueryFactory(entityManager: EntityManager) =
    JPAQueryFactory(JPQLTemplates.DEFAULT, entityManager)

// 테스트 126곳
val queryFactory = JPAQueryFactory(testEntityManager.entityManager)
```

앱은 `JPQLTemplates.DEFAULT`로, 테스트는 자동 감지 템플릿으로 JPQL을 만들었습니다. QueryDSL 코드는 같았습니다. 그러나 테스트가 검증한 JPQL은 앱이 실행하는 JPQL과 다를 수 있었습니다. 이 차이가 두 방향으로 나타났습니다.

- 앱에서만 실패하는 쿼리가 테스트를 통과했습니다. 차이 1의 빈 select, 차이 2의 `CaseBuilder` 상수 합계가 여기 해당합니다.
- 테스트에서만 실패하는 쿼리가 앱 코드에서 고쳐졌습니다. 전환 작업 때 `transform` 9곳을 걷어냈는데, 앱의 템플릿에서는 동작하는 코드였습니다.

500을 낸 검색 API는 차이 1에 해당했습니다. 이 쿼리는 Spring Boot 2 시절과 같은 코드였습니다. 그때는 앱도 자동 감지 템플릿을 썼으므로 정상이었습니다. 전환 뒤에도 테스트는 자동 감지 템플릿으로 돌아 계속 통과했습니다. 전환 전후의 응답을 대조하는 검증도 했습니다. 다만 그 검증은 이 하위 쿼리가 붙는 조건으로 검색을 호출하지 않았습니다. 그래서 전환 검증에서 걸리지 않았고, QA의 회귀 테스트에서 발견됐습니다.

## 해결 방법: 테스트도 앱과 같은 템플릿으로 만든다

앱과 테스트의 템플릿을 같게 맞춰야 합니다. 맞추는 방향은 두 가지였습니다.

| 방법 | 내용 | 판단 |
|---|---|---|
| 앱을 테스트에 맞춤 | 앱의 빈을 자동 감지 템플릿으로 되돌림 | 택하지 않음. 앱의 모든 QueryDSL 쿼리 문자열이 한꺼번에 바뀌고, Hibernate 5 API를 부르는 `HibernateHandler`가 앱에 돌아옴 |
| 테스트를 앱에 맞춤 | 테스트 126곳을 `JPQLTemplates.DEFAULT`로 만듦 | 택함. 앱 코드는 그대로이고, 테스트가 앱과 같은 JPQL을 검증함 |

테스트 126곳에 `JPQLTemplates.DEFAULT`를 넘기고 전체 테스트를 실행했습니다. 바꾸기 전 결과와 비교해 새로 실패한 테스트는 2건이었습니다. 2건 모두 500을 낸 검색 쿼리를 검증하는 테스트였습니다. 템플릿을 맞추자 테스트가 앱의 오류를 드러냈습니다.

쿼리는 `select()`를 `selectOne()`으로 바꿔 고쳤습니다.

```kotlin
JPAExpressions.selectOne()
    .from(stock)
    .where(stock.product.eq(product), stock.quantity.gt(0))
    .exists()
```

`selectOne()`은 select 목록에 상수 1을 넣습니다. `JPQLTemplates.DEFAULT`에서는 이 상수도 바인드 파라미터로 나갈 수 있습니다. 다만 Hibernate 6은 이 문자열을 받아들였습니다. 앱과 같은 템플릿으로 돈 테스트 2건도 통과했습니다. `exists`는 행이 있는지만 보므로 select 목록의 값은 결과에 영향을 주지 않습니다. 빈 `select()`로 존재 여부를 확인하는 코드는 전체에서 이 한 곳뿐이었습니다.

`CaseBuilder` 상수 합계는 `Expressions.numberTemplate`으로 바꿨습니다. 1과 0을 JPQL 문자열에 직접 적으므로 템플릿과 상관없이 리터럴로 나갑니다. 결과 타입은 `Long`입니다.

```kotlin
val inStockCount = Expressions.numberTemplate(
    Long::class.java,
    "coalesce(sum(case when {0} then 1 else 0 end), 0)",
    stock.quantity.gt(0),
)
```

## 재발 방지: 템플릿 없는 생성을 CI에서 막는다

테스트를 고쳐도, 다음에 누군가 `JPAQueryFactory(entityManager)`로 테스트를 새로 만들면 같은 차이가 다시 생깁니다. 그래서 CI에 검사 스크립트를 추가했습니다. 테스트 코드에서 템플릿 인자 없이 `JPAQueryFactory`를 만드는 줄이 있으면 빌드가 실패합니다.

## 이후의 변화: 앱의 템플릿을 자동 감지로 되돌림

위 해결은 2026년 10월 초 기준입니다. 2주 뒤 기준이 바뀌었습니다.

QueryDSL을 OpenFeign이 관리하는 포크 6.12로 교체했습니다. 이 포크의 `HibernateHandler`는 `ScrollableResults.get(int)`를 호출하지 않고 `getResultList()`로 결과를 가져옵니다. 차이 3의 `NoSuchMethodError` 원인이 사라졌습니다.

그래서 앱의 빈을 `JPAQueryFactory(entityManager)`로 되돌렸습니다. 테스트 128개 파일도 템플릿 인자를 빼서 앱과 같게 맞췄습니다. CI 검사는 반대로 바뀌어, 이제 `JPQLTemplates.DEFAULT`를 쓰면 실패합니다. CASE 식 안의 상수도 다시 리터럴로 나갑니다. 차이 2를 피하려고 바꾼 `numberTemplate` 코드는 되돌리지 않고 두었습니다.

기준 템플릿이 `JPQLTemplates.DEFAULT`에서 자동 감지로 옮겨 갔을 뿐, 원칙은 그대로입니다. 앱과 테스트는 같은 템플릿으로 쿼리를 만들어야 합니다.

## 남은 한계: 테스트 DB는 H2

템플릿은 맞췄지만 테스트 DB는 H2이고, 앱의 DB는 MariaDB입니다. 테스트는 앱과 같은 JPQL을 검증하지만, Hibernate가 그 JPQL을 H2용 SQL로 바꿔 실행합니다. H2와 MariaDB의 SQL 처리 차이로 생기는 오류는 이 테스트로 잡을 수 없습니다.

CI 검사에도 한계가 있습니다. 검사는 한 줄 단위로 동작합니다. `JPAQueryFactory(`와 템플릿 인자를 줄을 나눠 쓰면 잘못 판정합니다.

## 마치며

이번 오류의 원인은 앱과 테스트가 서로 다른 템플릿을 쓴 데 있었습니다. 어느 템플릿도 Hibernate 6에서 모든 패턴을 받지 못합니다. 그래서 어느 템플릿을 고르든, 테스트가 앱과 같은 템플릿으로 돌아야 실패가 드러납니다. 테스트 126곳의 템플릿을 맞추자 새로 실패한 테스트는 2건이었습니다. 그 2건이 QA가 찾은 오류를 검증하는 테스트였습니다.

QueryDSL 5.0.0과 Hibernate 6.4.4 조합에서 확인한 내용이라, 다른 버전에서는 동작이 다를 수 있습니다. 틀린 부분이 있으면 알려 주시면 고치겠습니다.

## 참고 문헌

- QueryDSL 5.0.0, [`JPAProvider.java`](https://github.com/querydsl/querydsl/blob/QUERYDSL_5_0_0/querydsl-jpa/src/main/java/com/querydsl/jpa/impl/JPAProvider.java): 템플릿 자동 감지
- QueryDSL 5.0.0, [`HQLTemplates.java`](https://github.com/querydsl/querydsl/blob/QUERYDSL_5_0_0/querydsl-jpa/src/main/java/com/querydsl/jpa/HQLTemplates.java): `HibernateHandler` 선택과 `isCaseWithLiterals()`
- QueryDSL 5.0.0, [`JPQLTemplates.java`](https://github.com/querydsl/querydsl/blob/QUERYDSL_5_0_0/querydsl-jpa/src/main/java/com/querydsl/jpa/JPQLTemplates.java): `DEFAULT`와 `DefaultQueryHandler`
- QueryDSL 5.0.0, [`ScrollableResultsIterator.java`](https://github.com/querydsl/querydsl/blob/QUERYDSL_5_0_0/querydsl-jpa/src/main/java/com/querydsl/jpa/ScrollableResultsIterator.java): `ScrollableResults.get(int)` 호출
- Hibernate ORM 6.4, [`ScrollableResults` Javadoc](https://docs.jboss.org/hibernate/orm/6.4/javadocs/org/hibernate/ScrollableResults.html)
- OpenFeign QueryDSL 6.12, [`HibernateHandler.java`](https://github.com/OpenFeign/querydsl/blob/6.12/querydsl-libraries/querydsl-jpa/src/main/java/com/querydsl/jpa/HibernateHandler.java)
