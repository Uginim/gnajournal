---
title: '억울한 EXISTS, EXISTS 문은 IN 절보다 느릴까?'
description: 'EXISTS를 IN으로 바꾸면 빨라진다는 통념을 따져봅니다. 성능 개선과 원인 입증은 다른 문제라는 것, 그리고 동등한 서브쿼리 IN과 EXISTS가 현대 MySQL에서 같은 최적화 후보가 되는 것을 로컬 실측으로 확인합니다.'
pubDate: 'Jul 24 2026'
heroImage: '../../assets/in-vs-exists-mysql-mariadb-hero.png'
tags: ['데이터베이스', 'MySQL', 'MariaDB', '쿼리최적화', 'SQL']
draft: false
---

예전에 제가 만든 제품에 목록 조회 기능이 하나 있었습니다. 데이터가 추가되고 필터가 추가될수록 점점 느려지고 있었습니다. 새로 팀에 합류한 분이 온보딩할 때, 그 기능을 개선하는 작업을 맡았습니다. 그 기능의 조회 쿼리는 필터마다 `EXISTS` 조건이 붙어 있었습니다. 그는 EXISTS를 걷어내는 선택을 했고, IN으로 바꾸자 쿼리는 실제로 빨라졌습니다. 문제는 그다음에 내려진 결론이었습니다. "EXISTS를 써서 느렸다. 앞으로는 IN을 쓰자."라고 팀의 기조가 정해져버렸던 겁니다.

쿼리는 빨라졌고, EXISTS는 범인으로 남았습니다. 하지만 전후의 코드를 펼쳐보면 사라진 것은 EXISTS뿐이 아니었습니다. 인덱스가 추가됐고, 하나의 쿼리가 여러 단계로 나뉘었으며, COUNT 처리 방식도 달라졌습니다.

빨라졌다는 결과는 분명했지만, 그 결과만으로 원인까지 알 수는 없었습니다. 무엇이 실제로 달라졌는지 하나씩 분리해보고, EXISTS 자체가 느렸는지도 다시 확인해봤습니다.

> 환경 표기는 MySQL 8.0 / MariaDB 기준입니다.

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

이 EXISTS들이 한꺼번에 생긴 것은 아니었습니다. 필터 하나를 추가하는 작은 변경이 반복됐고, 각 변경은 당시 데이터에서는 성능 문제가 보이지 않아 리뷰를 통과했습니다. 문제는 개별 변경보다 그 패턴이 누적된 최종 구조에서 드러났습니다. 그 시점에는 이미 같은 모양의 서브쿼리가 여러 개였고, 서브쿼리가 탈 인덱스도 충분하지 않았으며, 데이터도 꾸준히 늘어 있었습니다.

이렇게 누적된 구조가 결국 개선 대상이 됐습니다.

## 빨라진 이유는 하나가 아니었다

개선 과정에서는 다음 조건들이 함께 바뀌었습니다.

- 여러 서브쿼리에 흩어져 있던 조건을 ID 조회 쿼리로 모았다
- 페이지 대상 조회와 엔티티 로드, `COUNT` 처리를 분리했다
- 부족했던 인덱스를 보강했다
- 당시에는 조회된 ID가 적어 `IN` 목록도 작았다

즉 `EXISTS` 하나만 걷어낸 통제된 실험이 아니었습니다. 여러 조건이 동시에 바뀌었기 때문에, 어느 변화가 얼마나 기여했는지는 당시 측정 자료 없이는 알 수 없습니다. 적어도 EXISTS 하나를 원인으로 지목할 근거는 없었습니다. 그런데 결론은 "EXISTS가 느렸다"로 났고, 이후 코드 리뷰에서는 EXISTS가 보이면 IN으로 바꾸라는 말이 따라붙었습니다.

## 당시 바꾼 것은 문법 교체가 아니었다

쿼리를 개선할 수 있는 선택지는 세 가지였습니다.

1. 비슷한 EXISTS를 여러 개 쌓는 기존 구조
2. 관련 조건을 하나로 합친 통합 EXISTS
3. 필요한 ID를 먼저 조회해 애플리케이션에서 IN 목록으로 넘기는 구조

당시 택한 것은 3번입니다. "EXISTS 대 IN"이라는 이분법은 1번과 2번을 같은 것으로 뭉갭니다. 그러나 문제의 핵심은 EXISTS 사용 여부보다, 1번처럼 비슷한 서브쿼리가 누적된 구조에 가까웠습니다. 2번, 즉 통합 EXISTS도 얼마든지 대안이 될 수 있었습니다. 이 글이 변호하려는 것은 "기존 쿼리가 완벽했다"가 아니라 "EXISTS라는 문법 자체는 죄인이 아니었다"입니다.

게다가 3번은 EXISTS를 같은 의미의 IN으로 바꿔 쓴 것이 아니었습니다. 앞서 본 여러 변경과 함께, 하나의 쿼리로 처리하던 조회를 ID 사전 조회부터 여러 단계로 나눈 재편이었습니다. SQL 문법 하나를 교체한 것이 아니라 실행 구조 자체를 바꾼 것입니다.

이 글에서 구분해야 할 IN은 두 형태입니다. 당시 사용한 것은 애플리케이션이 미리 조회한 값을 `IN (?, ?, ...)`으로 전달하는 값 목록 IN입니다. 반면 EXISTS와 논리적으로 대응하는 것은 `IN (SELECT ...)` 형태의 서브쿼리 IN입니다. 둘은 같은 IN이라는 이름을 쓰지만 실행 구조가 다릅니다. 따라서 당시의 개선은 EXISTS와 IN의 문법 비교가 아니라, 하나의 쿼리로 처리하던 구조와 애플리케이션을 거쳐 여러 쿼리로 나눈 구조의 비교에 가까웠습니다.

## EXISTS는 느린 문법이 아니다

그렇다면 실행 구조를 그대로 둔 채, 논리적으로 동등한 EXISTS와 서브쿼리 IN을 비교하면 어떨까요? 동등하고 변환 조건을 충족하는 서브쿼리 IN과 EXISTS는 현대 MySQL, MariaDB에서 같은 최적화 후보가 됩니다. 옵티마이저가 둘을 semijoin이라는 같은 형태로 바꾼 뒤 비용으로 전략을 고르기 때문입니다. `LIMIT`, 집계, `HAVING` 같은 제약이 없고 서로 동등한 경우입니다. MySQL 문서는 8.0.16부터 EXISTS 서브쿼리가 동등한 IN 서브쿼리와 같은 semijoin 변환을 받는다고 적습니다.

로컬 MariaDB 11.4에서 최소 재현으로 확인했습니다. 조회 대상 `big`(100만 행, `gid`에 인덱스)과 값 집합 `sub`(5만 행)를 만들었습니다.

```sql
big  (id PK, gid, KEY(gid))     -- 조회 대상, 100만 행
sub  (id PK)                    -- 값 집합, 5만 행
```

`gid`가 `sub`에 있는 값과 일치하는 `big` 행을 세는 같은 질문을, 서브쿼리 IN과 EXISTS로 각각 썼습니다. 여기에 같은 `sub` 값을 그대로 나열한 값 목록 IN을 하나 더 두고 비교했습니다.

```sql
-- 서브쿼리 IN
SELECT COUNT(*) FROM big WHERE gid IN (SELECT id FROM sub);

-- EXISTS
SELECT COUNT(*) FROM big b WHERE EXISTS (SELECT 1 FROM sub s WHERE s.id = b.gid);

-- 값 목록 IN: 같은 sub 값을 그대로 나열 (5만 개)
SELECT COUNT(*) FROM big WHERE gid IN (0, 4, 8, /* ... */ 199996);
```

서브쿼리 IN과 EXISTS는 `EXPLAIN`에서 같은 실행계획을 보였고, 값 목록 IN은 실행계획이 달랐습니다. 실행 계획만으로는 실제 작업량을 알 수 없어, 편차 없는 지표인 Handler 카운터로 세 방식이 읽은 행 수를 셌습니다(`FLUSH STATUS` 후 세션 상태 확인). 실제 시간은 편차가 커서, 12번씩 측정한 시간의 중앙값을 함께 실었습니다.

| 방식 | Handler_read_key | Handler_read_next | Rows_read | Rows_tmp_read | 시간 중앙값 |
|---|---|---|---|---|---|
| IN 서브쿼리 | 50,000 | 249,275 | 299,275 | 0 | 약 59ms |
| EXISTS | 50,000 | 249,275 | 299,275 | 0 | 약 59ms |
| 값 목록 IN 5만 | 50,000 | 249,275 | 249,275 | 50,000 | 약 81ms |

이 실험에서는 서브쿼리 IN과 EXISTS가 같은 실행계획과 동일한 Handler 카운터를 보였고, 시간도 약 59ms로 사실상 같았습니다. 문법만 다를 뿐 실행은 갈리지 않았습니다. 반면 같은 값을 그대로 나열한 값 목록 IN은 인덱스 작업은 같지만 `Rows_tmp_read`가 5만이고, 시간도 약 81ms로 더 느렸습니다. MariaDB가 이 5만 개짜리 값 목록 IN을 임시 테이블을 쓰는 서브쿼리 형태로 변환했기 때문입니다(Materialization). 서브쿼리 IN과 EXISTS는 이미 인덱스가 있는 실제 테이블을 바로 씁니다. 다만 이건 값이 많을 때의 이야기입니다. 당시 팀이 쓴 것과 같은 종류의 값 목록 IN이지만 목록 크기가 작았으므로, 당시에도 같은 비용이 났다고 볼 수는 없습니다. 값 목록 IN은 시간 편차도 커서 가끔 200ms를 넘겼습니다. 이 시간은 노트북에서 잰 값이라 절대치가 아니라 세 방식의 상대 차이로만 봐야 합니다.

## 그래도 어느 한쪽이 항상 빠르진 않다

EXISTS가 언제나 빠르다는 뜻은 아닙니다. 반대로 IN이 언제나 빠르다는 뜻도 아닙니다.

값 목록 IN이 작을 때는 빠릅니다. 그러나 데이터가 늘어 리스트가 수천에서 수만 개가 되면, 값을 앱과 주고받는 왕복 비용, 커진 SQL 문자열의 파싱, 그리고 위에서 본 임시 테이블 비용이 붙습니다. 값 개수가 바뀔 때마다 실행계획을 재사용하지 못하는 문제도 있습니다.

로컬에서 사건과 비슷한 조건으로도 재봤습니다. ID를 먼저 조회해 값 목록 IN으로 넘기는 방식과, 조건을 하나로 합친 통합 EXISTS를 비교했습니다. 두 방식은 같은 결과를 냈고 읽은 행 수도 비슷했지만, IN 패턴은 임시 테이블 하나와 앱과 DB 사이 왕복 한 번이 더 붙었습니다. 이 조건에서는 통합 EXISTS가 군더더기가 적었습니다. 다만 이것도 한 조건의 관찰이므로, 여기서 "IN은 몇 개부터 느리다" 같은 임계값을 만들 수는 없습니다.

임계점은 데이터 분포와 선택도, 인덱스, DB 버전, 정렬과 `LIMIT`, 대상 컬럼의 유일성, 드라이버의 파라미터 전달 방식에 따라 달라집니다. 같은 쿼리가 개발 DB와 운영 DB의 마이너 버전 차이만으로 결과가 뒤집히기도 합니다. 결국 실행계획은 문법의 이름이 아니라 이 조건들이 정합니다.

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

## 부록: JPA에서 값 목록 IN의 크기와 파싱

값 목록 IN을 JPA로 쓸 때 한 가지 더 붙는 비용이 있습니다. JPA는 쿼리를 PreparedStatement로 실행합니다. 값을 SQL에 직접 넣지 않고 `?` 자리에 바인딩하기 때문에, `where id in :ids`는 리스트 원소 개수만큼 `?`가 생깁니다. 크기가 3이면 `in (?, ?, ?)`, 5면 `in (?, ?, ?, ?, ?)`입니다. PreparedStatement는 같은 SQL 텍스트를 재사용해 이득을 보는데, IN 개수가 바뀌면 `?` 개수가 달라져 SQL 텍스트가 바뀝니다. 그래서 그 이득을 못 보고 서버가 매번 새로 파싱합니다.

Hibernate 6에 로컬 MariaDB를 붙여, 크기 3, 5, 6, 7을 각각 두 번씩 실행하며 서버가 새로 파싱한 횟수(`Com_stmt_prepare` 증가)를 셌습니다. `hibernate.query.in_clause_parameter_padding`을 켜면 크기를 2의 거듭제곱으로 채워 서로 다른 SQL 가짓수를 줄입니다.

| in_clause_parameter_padding | 서로 다른 SQL | Com_stmt_prepare 증가 |
|---|---|---|
| false (기본값) | 4종류 (물음표 3, 5, 6, 7개) | +4 |
| true | 2종류 (물음표 4개, 8개) | +2 |

같은 크기를 두 번 실행해도 파싱은 SQL 종류 수만큼만 늘었습니다. 두 번째 실행은 같은 SQL이라 캐시 적중입니다. padding은 서로 다른 SQL 가짓수를 줄여 이 적중률을 올립니다. 재현 코드는 참고 문헌의 gist에 있습니다.

## 참고 문헌

- [MySQL, Optimizing IN and EXISTS Subquery Predicates with Semijoin Transformations](https://dev.mysql.com/doc/refman/8.0/en/semijoins.html): semijoin은 준비 단계 변환이며 비용 기반으로 전략을 선택한다. 8.0.16부터 EXISTS도 IN과 같은 변환을 받는다.
- [MySQL, Optimizing Subqueries with Materialization](https://dev.mysql.com/doc/refman/8.0/en/subquery-materialization.html): 과거 `IN`을 상관 `EXISTS`로 재작성하던 동작과, 서브쿼리 Materialization.
- [MariaDB, Semi-join Subquery Optimizations](https://mariadb.com/kb/en/semi-join-subquery-optimizations/): semi-join 최적화(기본 활성)와 전략들.
- [MariaDB, EXISTS-to-IN Optimization](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/subquery-optimizations/exists-to-in-optimization): 조건을 만족하는 EXISTS를 IN으로 변환해 semijoin, materialization 등의 최적화 후보를 쓸 수 있게 한다.
- [MariaDB, Conversion of Big IN Predicates Into Subqueries](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/query-optimizations/subquery-optimizations/conversion-of-big-in-predicates-into-subqueries): 값이 많은 IN 조건을 임시 테이블을 쓰는 서브쿼리 형태로 변환한다. 이 글의 5만 개 값 목록 IN 실험이 이 경우다.
- [재현 코드 (Hibernate + MariaDB)](https://gist.github.com/Uginim/9b85b93f8daea512d3e74e2d29ab4f3e): IN 크기별 생성 SQL과 `Com_stmt_prepare` 비교, IN 서브쿼리와 EXISTS의 Handler 카운터 대조. 이 글의 재현 표가 나온 스크립트.
