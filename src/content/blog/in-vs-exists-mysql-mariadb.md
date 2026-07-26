---
title: '억울한 EXISTS, 정말 IN보다 느릴까?'
description: 'EXISTS를 IN으로 바꾸면 빨라진다는 통념을 따져봅니다. 성능 개선과 원인 입증은 다른 문제라는 것, 그리고 동등한 서브쿼리 IN과 EXISTS가 현대 MySQL에서 같은 최적화 후보가 되는 것을 로컬 실측으로 확인합니다.'
pubDate: 'Jul 24 2026'
heroImage: '../../assets/in-vs-exists-mysql-mariadb-hero.png'
tags: ['데이터베이스', 'MySQL', 'MariaDB', '쿼리최적화', 'SQL']
draft: false
---

예전에 제가 만든 목록 조회 기능이 있었습니다. 데이터와 필터가 늘면서 점점 느려졌고, 새로 팀에 합류한 분이 그 개선을 맡았습니다. 개선 과정에서 여러 `EXISTS` 조건이 사라지고, 필요한 ID를 먼저 조회해 IN 리스트로 넘기는 구조가 도입됐습니다. 응답은 실제로 빨라졌습니다. 그리고 팀에는 "EXISTS를 써서 느렸다. 앞으로는 IN을 쓰자"는 결론이 남았습니다.

그 일을 계기로 EXISTS와 IN의 성능 차이를 문법만으로 설명할 수 있는지 살펴봤습니다. 당시 바뀐 쿼리 구조를 정리하고, 논리적으로 동등한 서브쿼리 IN과 EXISTS의 실행계획을 MariaDB에서 비교했습니다.

> MySQL 관련 설명은 8.0.16 이상, 실측은 MariaDB 11.4를 기준으로 합니다.

## 점점 느려지던 쿼리

그 기능은 목록을 페이지 단위로 조회하면서 "필터"로 결과를 좁히는 화면이었습니다. 필터는 선택한 값들의 묶음이고, 필터가 하나 늘 때마다 EXISTS 서브쿼리가 하나씩 붙었습니다. "이 필터에 해당하는 항목만"을 EXISTS로 표현하는 게 직관적이었기 때문입니다. JPA를 썼기 때문에 코드는 QueryDSL이었습니다.

```java
BooleanBuilder filters = new BooleanBuilder();

// 필터가 선택될 때마다 EXISTS 조건을 하나씩 더한다
if (categoryIds != null) {
    filters.and(JPAExpressions.selectOne()
        .from(itemCategory)
        .where(itemCategory.itemId.eq(item.id), itemCategory.categoryId.in(categoryIds))
        .exists());
}
if (regionIds != null) {
    filters.and(JPAExpressions.selectOne()
        .from(itemRegion)
        .where(itemRegion.itemId.eq(item.id), itemRegion.regionId.in(regionIds))
        .exists());
}
// 필터가 늘면 이런 블록이 하나씩 더 붙는다

List<Item> page = queryFactory
    .selectFrom(item)
    .where(filters)
    .orderBy(item.createdAt.desc())
    .offset(offset).limit(size)
    .fetch();
```

이를 SQL로 변환하면 이렇습니다.

```sql
SELECT *
FROM   item i
WHERE  EXISTS (SELECT 1 FROM item_category c WHERE c.item_id = i.id AND c.category_id IN (:categoryIds))
  AND  EXISTS (SELECT 1 FROM item_region   r WHERE r.item_id = i.id AND r.region_id   IN (:regionIds))
ORDER BY i.created_at DESC
LIMIT :size OFFSET :offset;
```

예제에는 목록 조회만 남겼지만, 실제 기능에서는 전체 건수를 구하는 `COUNT` 쿼리도 함께 실행했습니다.

이 EXISTS들이 한꺼번에 생긴 것은 아니었습니다. 필터 하나를 추가하는 작은 변경이 반복됐고, 각 변경은 당시 데이터에서는 성능 문제가 보이지 않아 리뷰를 통과했습니다. 문제는 개별 변경보다 그 패턴이 누적된 최종 구조에서 드러났습니다. 그 시점에는 이미 같은 모양의 서브쿼리가 여러 개였고, 서브쿼리를 뒷받침할 인덱스도 충분하지 않았으며, 데이터도 꾸준히 늘어 있었습니다.

이렇게 누적된 구조가 결국 개선 대상이 됐습니다.

## 그 당시 개선은 어떻게 이뤄졌을까?

새로 팀에 합류한 분이 온보딩 과정에서 이 기능의 개선을 맡았습니다. 그분은 여러 EXISTS 조건을 걷어내고, 조건에 맞는 ID를 먼저 조회한 뒤 그 ID 목록으로 페이지 대상을 찾는 방식을 택했습니다. 이 과정에서 조회 구조도 함께 재편됐습니다.

- 여러 서브쿼리에 흩어져 있던 조건을 ID 조회 쿼리로 모았다
- 페이지 대상 조회와 엔티티 로드, `COUNT` 처리를 분리했다
- 부족했던 인덱스를 보강했다

당시에는 먼저 조회된 ID도 적어서 IN 리스트가 작았습니다. 개선된 기능의 응답은 실제로 빨라졌습니다.

문제는 그다음이었습니다. 개선 과정에서 함께 바뀐 다른 조건들은 사라지고, "EXISTS를 없애고 IN으로 바꾸자 빨라졌다"는 설명만 남았습니다. 이후 코드 리뷰에서는 EXISTS가 보이면 IN으로 바꾸라는 말이 따라붙었습니다. 제가 EXISTS를 사용한 선택 자체가 성능 문제의 원인처럼 취급되기 시작한 것입니다.

기존 쿼리에 개선할 부분이 있었던 것은 맞습니다. 그러나 그것이 곧 EXISTS를 선택한 것이 잘못이었다는 뜻은 아니었습니다. 실제 변경에서는 EXISTS 제거라는 변수 하나만 바뀐 것이 아니었기 때문에, 정당한 비교가 아니었습니다. 과학적인 변인 통제가 이뤄진 상황이 아니었습니다.

## 정말 EXISTS만 걷어낸 걸까?

이 목록 조회는 크게 세 가지 방식으로 짤 수 있었습니다.

1. 비슷한 EXISTS를 여러 개 쌓는 기존 구조
2. 관련 조건을 하나의 서브쿼리에 모은 통합 EXISTS
3. 필요한 ID를 먼저 조회해 애플리케이션에서 IN 리스트로 전달하는 구조

개선에서 택한 것은 3번입니다. 하지만 1번과 2번은 모두 EXISTS를 쓰면서도 실행 구조는 다릅니다. 따라서 EXISTS를 사용했다는 사실만으로 둘을 같은 쿼리로 취급할 수는 없습니다. 문제는 EXISTS라는 문법보다, 1번처럼 비슷한 서브쿼리가 계속 누적된 구조에 가까웠습니다. 상황에 따라 2번도 대안이 될 수 있었습니다.

여기서 구분해야 할 것은 기존 쿼리의 품질과 EXISTS 문법의 성능입니다. 기존 구조에 개선할 부분이 있었다는 사실이 EXISTS 자체가 느리다는 뜻은 아닙니다.

게다가 3번은 EXISTS를 같은 의미의 IN으로 바꿔 쓴 것이 아니었습니다. 앞서 본 여러 변경과 함께, 하나의 쿼리로 처리하던 조회를 ID 사전 조회부터 여러 단계로 나눈 재편이었습니다. SQL 문법 하나를 교체한 것이 아니라 실행 구조 자체를 바꾼 것입니다.

그런데 당시 쓴 IN은 EXISTS와 논리적으로 대응하는 형태가 아니었습니다. 같은 IN이라는 이름이지만 두 형태로 갈리기 때문입니다. 당시 사용한 것은 애플리케이션이 미리 조회한 값을 `IN (?, ?, ...)`으로 전달하는 IN 리스트이고, EXISTS와 논리적으로 대응하는 것은 `IN (SELECT ...)` 형태의 서브쿼리 IN입니다. 둘은 실행 구조가 다릅니다. 따라서 당시의 개선은 EXISTS와 IN의 문법 비교가 아니라, 하나의 쿼리로 처리하던 구조와 애플리케이션을 거쳐 여러 쿼리로 나눈 구조의 비교에 가까웠습니다.

## EXISTS는 느린 문법이 아니다

그렇다면 실행 구조를 그대로 둔 채, 논리적으로 동등한 EXISTS와 서브쿼리 IN을 비교하면 어떨까요? 동등하고 변환 조건을 충족하는 서브쿼리 IN과 EXISTS는 현대 MySQL, MariaDB에서 같은 최적화 후보가 됩니다. 옵티마이저가 둘을 semijoin이라는 같은 형태로 바꾼 뒤 비용으로 전략을 고르기 때문입니다. `LIMIT`, 집계, `HAVING` 같은 제약이 없고 서로 동등한 경우입니다. MySQL 문서는 8.0.16부터 EXISTS 서브쿼리가 동등한 IN 서브쿼리와 같은 semijoin 변환을 받는다고 적습니다.

로컬 MariaDB 11.4에서 최소 재현으로 확인했습니다. 조회 대상 `big`(100만 행, `gid`에 인덱스)과 값 집합 `sub`(5만 행)를 만들었습니다.

```sql
big  (id PK, gid, KEY(gid))     -- 조회 대상, 100만 행
sub  (id PK)                    -- 값 집합, 5만 행
```

`gid`가 `sub`에 있는 값과 일치하는 `big` 행을 세는 같은 질문을, 서브쿼리 IN과 EXISTS로 각각 썼습니다. 여기에 같은 `sub` 값을 그대로 나열한 IN 리스트를 하나 더 두고 비교했습니다.

```sql
-- 서브쿼리 IN
SELECT COUNT(*) FROM big WHERE gid IN (SELECT id FROM sub);

-- EXISTS
SELECT COUNT(*) FROM big b WHERE EXISTS (SELECT 1 FROM sub s WHERE s.id = b.gid);

-- IN 리스트: 같은 sub 값을 그대로 나열 (5만 개)
SELECT COUNT(*) FROM big WHERE gid IN (0, 4, 8, /* ... */ 199996);
```

서브쿼리 IN과 EXISTS는 `EXPLAIN`에서 같은 실행계획을 보였고, IN 리스트는 실행계획이 달랐습니다. `EXPLAIN`만으로는 실행 중 실제로 읽은 행 수를 확인하기 어려워, 실행 시간보다 변동이 적은 작업량 지표인 Handler 카운터도 함께 확인했습니다. Handler 카운터는 서버가 스토리지 엔진에서 행을 읽은 연산 횟수라, 같은 계획이면 실행할 때마다 값이 같아 시간보다 안정적입니다(확인 방법은 부록). 세 방식 모두 `gid`가 `sub`의 5만 값과 겹치는 249,275개 행이 결과였고, 각 쿼리를 워밍업 3번 뒤 같은 세션에서 12번씩 측정했습니다. 표의 시간은 그 측정의 중앙값입니다.

| 방식 | Handler_read_key | Handler_read_next | Rows_read | Rows_tmp_read | 시간 중앙값 |
|---|---|---|---|---|---|
| IN 서브쿼리 | 50,000 | 249,275 | 299,275 | 0 | 약 59ms |
| EXISTS | 50,000 | 249,275 | 299,275 | 0 | 약 59ms |
| IN 리스트 5만 | 50,000 | 249,275 | 249,275 | 50,000 | 약 81ms |

이 실험에서는 서브쿼리 IN과 EXISTS가 같은 실행계획과 동일한 Handler 카운터를 보였고, 시간도 약 59ms로 사실상 같았습니다. 문법만 다를 뿐 실행은 갈리지 않았습니다. 반면 같은 값을 그대로 나열한 IN 리스트는 인덱스 작업은 같지만 `Rows_tmp_read`가 5만이고, 시간도 약 81ms로 더 느렸습니다. MariaDB가 이 5만 개짜리 IN 리스트를 임시 테이블을 쓰는 서브쿼리 형태로 변환했기 때문입니다(Materialization). 서브쿼리 IN과 EXISTS는 이미 인덱스가 있는 실제 테이블을 바로 씁니다. 다만 이건 값이 많을 때의 이야기입니다. 당시 팀이 쓴 것과 같은 종류의 IN 리스트지만 목록 크기가 작았으므로, 당시에도 같은 비용이 났다고 볼 수는 없습니다. 이 시간은 노트북에서 잰 값이라 절대치가 아니라 세 방식의 상대 차이로만 봐야 합니다.

## 그래도 어느 한쪽이 항상 빠르진 않다

EXISTS가 언제나 빠르다는 뜻은 아닙니다. 반대로 IN이 언제나 빠르다는 뜻도 아닙니다.

IN 리스트가 작으면 효율적일 수 있습니다. 그러나 데이터가 늘어 리스트가 수천에서 수만 개가 되면, 값을 앱과 주고받는 왕복 비용, 커진 SQL 문자열의 파싱, 그리고 위에서 본 임시 테이블 비용이 붙습니다. 값 개수가 바뀔 때마다 실행계획을 재사용하지 못하는 문제도 있습니다.

옵티마이저의 선택은 데이터 분포와 선택도, 인덱스, DB 버전, 정렬과 `LIMIT`, 대상 컬럼의 유일성 등에 따라 달라질 수 있습니다. 결국 실행계획을 결정하는 것은 문법의 이름 하나가 아니라 이러한 조건들의 조합입니다.

### JPA에서 IN 리스트의 크기와 파싱

IN 리스트를 JPA로 쓸 때 한 가지 더 붙는 비용이 있습니다. JPA는 쿼리를 PreparedStatement로 실행합니다. 값을 SQL에 직접 넣지 않고 `?` 자리에 바인딩하기 때문에, `where id in :ids`는 리스트 원소 개수만큼 `?`가 생깁니다. 크기가 3이면 `in (?, ?, ?)`, 5면 `in (?, ?, ?, ?, ?)`입니다. IN 리스트의 크기가 달라지면 SQL 텍스트도 달라지므로, 같은 prepared statement나 statement cache 항목을 재사용하기 어려워질 수 있습니다.

Hibernate 6에 로컬 MariaDB를 붙여, 크기 3, 5, 6, 7을 각각 두 번씩 실행하며 서버가 새로 파싱한 횟수(`Com_stmt_prepare` 증가)를 셌습니다.

| in_clause_parameter_padding | 서로 다른 SQL | Com_stmt_prepare 증가 |
|---|---|---|
| false (기본값) | 4종류 (물음표 3, 5, 6, 7개) | +4 |
| true | 2종류 (물음표 4개, 8개) | +2 |

이 실험 환경에서는 같은 크기의 목록을 두 번째로 실행했을 때 추가 prepare가 발생하지 않았습니다. `hibernate.query.in_clause_parameter_padding`을 켜자 서로 다른 SQL 텍스트의 수가 4개에서 2개로 줄었습니다. 재현 코드는 참고 문헌의 gist에 있습니다.

## 그렇다면 어떻게 판단할까?

IN과 EXISTS 중 하나를 팀의 기본 규칙으로 정할 수는 없습니다. 같은 의미의 쿼리도 인덱스, 데이터 분포, `LIMIT`, DB 엔진과 버전에 따라 실행계획이 달라질 수 있기 때문입니다. 판단의 기준은 SQL 문법의 이름이 아니라 실제 실행계획과 측정 결과여야 합니다.

- **실행계획을 확인한다**: "느릴 것 같다"는 예상보다 `EXPLAIN`과 `EXPLAIN ANALYZE`로 실제 접근 방식과 읽은 행 수를 확인한다.
- **같은 환경에서 비교한다**: 운영과 같은 엔진, 버전, 인덱스와 비슷한 데이터 분포에서 측정한다.
- **조건을 하나씩 바꾼다**: 인덱스, 쿼리 구조와 조회 방식을 동시에 바꾸면 무엇이 효과였는지 분리할 수 없다.
- **여러 번 반복한다**: 한 번의 응답 시간은 락이나 캐시 상태의 영향을 받을 수 있으므로 실행계획과 반복 측정 결과를 함께 본다.
- **반복되는 구조를 점검한다**: EXISTS라는 문법보다 비슷한 서브쿼리가 계속 추가되는 구조 자체가 더 큰 문제일 수 있다.

### 실행계획이 같다면 의미가 분명한 쪽을 고른다

동등한 서브쿼리 IN과 EXISTS가 같은 실행계획으로 처리된다면, 성능보다 쿼리의 의도와 NULL 동작을 기준으로 선택할 수 있습니다. 존재 여부를 묻는 조건에는 EXISTS가 의미를 직접 드러냅니다. 특히 부정 조건에서는 서브쿼리 결과에 `NULL`이 포함될 경우 `NOT IN`이 예상과 다르게 빈 결과를 낼 수 있으므로, `NOT EXISTS`가 더 안전한 경우가 많습니다.

## 결론

당시 쿼리에는 개선할 부분이 있었고, 새 구현은 실제로 더 빨랐습니다. 그러나 개선 과정에서는 EXISTS만 제거된 것이 아니라 쿼리 구조, 인덱스, 조회 단계와 COUNT 처리 방식이 함께 바뀌었습니다. 따라서 확인할 수 있는 것은 "새 구현이 더 빨랐다"는 사실까지입니다. "기존 구현이 EXISTS 때문에 느렸다"는 인과관계까지 입증된 것은 아니었습니다.

논리적으로 동등한 서브쿼리 IN과 EXISTS를 같은 조건에서 비교했을 때는 실행계획과 작업량, 실행 시간이 같았습니다. 적어도 EXISTS라는 문법 자체가 IN보다 느리다는 일반 법칙은 성립하지 않았습니다. 물론 특정 EXISTS 쿼리가 느릴 수는 있습니다. 하지만 그때 확인해야 할 것은 EXISTS라는 키워드가 아니라 실행계획, 인덱스, 데이터 분포와 반복된 쿼리 구조입니다.

따라서 팀의 규칙도 "EXISTS 대신 IN을 쓴다"가 아니라 다음과 같아야 합니다.

> 성능을 SQL 문법의 이름으로 판단하지 않는다. 실제 실행계획을 확인하고, 변경 조건을 분리해 측정한다.

EXISTS가 억울했던 이유는 절대로 느릴 수 없는 문법이어서가 아닙니다. 확인되지 않은 원인을 혼자 떠안았기 때문입니다.

## 부록: Handler 카운터 확인하기

실측에 쓴 Handler 카운터는 세션 상태 변수라 다음처럼 확인합니다.

```sql
FLUSH STATUS;                     -- 세션 카운터를 0으로 초기화
SELECT ... ;                      -- 재려는 쿼리를 한 번 실행
SHOW SESSION STATUS WHERE Variable_name
  IN ('Handler_read_key', 'Handler_read_next', 'Rows_read', 'Rows_tmp_read');
```

표에 쓴 값들의 뜻은 이렇습니다.

- `Handler_read_key`: 인덱스로 특정 행을 찾은 횟수. 인덱스 조회의 시작점 수.
- `Handler_read_next`: 인덱스 순서로 다음 행을 읽은 횟수. 범위 스캔에서 훑은 양.
- `Rows_read`: 읽은 전체 행 수.
- `Rows_tmp_read`: 내부 임시 테이블에서 읽은 행 수. 임시 테이블이 생겼는지 드러난다.

같은 데이터와 실행계획이면 이 값들은 실행할 때마다 똑같이 나옵니다. 벽시계 시간과 달리 편차가 없어, 각 쿼리가 실제로 행을 몇 번 만졌는지 비교하기에 안정적입니다.

## 참고 문헌

- [MySQL, Optimizing IN and EXISTS Subquery Predicates with Semijoin Transformations](https://dev.mysql.com/doc/refman/8.0/en/semijoins.html): semijoin은 준비 단계 변환이며 비용 기반으로 전략을 선택한다. 8.0.16부터 EXISTS도 IN과 같은 변환을 받는다.
- [MySQL, Optimizing Subqueries with Materialization](https://dev.mysql.com/doc/refman/8.0/en/subquery-materialization.html): 과거 `IN`을 상관 `EXISTS`로 재작성하던 동작과, 서브쿼리 Materialization.
- [MariaDB, Semi-join Subquery Optimizations](https://mariadb.com/kb/en/semi-join-subquery-optimizations/): semi-join 최적화(기본 활성)와 전략들.
- [MariaDB, EXISTS-to-IN Optimization](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/subquery-optimizations/exists-to-in-optimization): 조건을 만족하는 EXISTS를 IN으로 변환해 semijoin, materialization 등의 최적화 후보를 쓸 수 있게 한다.
- [MariaDB, Conversion of Big IN Predicates Into Subqueries](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/subquery-optimizations/conversion-of-big-in-predicates-into-subqueries): 값이 많은 IN 조건을 임시 테이블을 쓰는 서브쿼리 형태로 변환한다. 이 글의 5만 개 IN 리스트 실험이 이 경우다.
- [재현 코드 (Hibernate + MariaDB)](https://gist.github.com/Uginim/9b85b93f8daea512d3e74e2d29ab4f3e): IN 크기별 생성 SQL과 `Com_stmt_prepare` 비교, IN 서브쿼리와 EXISTS의 Handler 카운터 대조. 이 글의 재현 표가 나온 스크립트.
