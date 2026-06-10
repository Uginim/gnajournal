---
title: 'JPA N+1 문제, 세 가지 해결법 비교 (@EntityGraph / JPQL / QueryDSL)'
description: 'JPA에서 N+1 문제를 해결하는 @EntityGraph, JPQL fetch join, QueryDSL을 검증 시점·안전성·적합한 상황 기준으로 비교합니다. 언제 무엇을 쓸지 정리했습니다.'
pubDate: 'Jun 11 2026'
heroImage: '../../assets/jpa-n-plus-one-hero.png'
tags: ['JPA', 'Spring', 'QueryDSL', 'Kotlin', '백엔드']
draft: false
---

N+1 문제는 JPA를 사용할 때 자주 마주치는 성능 문제입니다. **목록 조회 1번(1) + 각 항목에 대한 추가 조회(N)** 로 인해 쿼리가 1 + N번 실행되는 현상으로, 목록의 크기가 커질수록 쿼리 수가 비례하여 증가해 성능에 영향을 줍니다.

이 글에서는 연관 데이터를 최초 쿼리에서 함께 조회하여 N+1을 방지하는 세 가지 작성 방식, `@EntityGraph`·JPQL의 fetch join·QueryDSL을 비교합니다. 세 방식 모두 목표는 같지만 **검증 시점**과 **적합한 상황**이 달라, 어떤 경우에 무엇을 쓰면 좋을지 정리합니다.

## N+1 문제란

먼저 어떤 현상인지 살펴보겠습니다. 게시글(`Post`)과 작성자(`Member`)가 연관 관계에 있다고 가정합니다.

```kotlin
val posts = postRepository.findAll()        // 쿼리 1번 (게시글 N개)
posts.forEach { println(it.member.name) }   // member 접근 시마다 쿼리 N번
```

각 게시글이 서로 다른 작성자를 참조한다고 가정하면, 게시글 100개를 조회할 때 작성자를 조회하기 위해 최대 100번의 추가 쿼리가 실행됩니다. 합계 101번이며, 이것이 N+1 문제입니다. (여러 게시글이 같은 작성자를 참조하는 경우, 이미 영속성 컨텍스트에 로딩된 작성자는 다시 조회하지 않으므로 추가 쿼리는 그보다 줄어듭니다.)

### 어떤 경우에 발생하나

공통점은 하나입니다. **목록(N개)을 조회한 뒤, 각 항목의 연관 엔티티에 다시 접근하는 시점**입니다. 구체적으로는 다음과 같은 상황입니다.

- **컬렉션을 조회한 뒤 반복문에서 연관 객체에 접근하는 경우** — 위 예시처럼 게시글 목록을 순회하며 `post.member`에 접근하는 경우로, 가장 일반적입니다.
- **`@OneToMany` 컬렉션을 순회하는 경우** — 게시글 하나에 연관된 댓글 목록(`post.comments`)을 게시글마다 조회하면, 게시글 수만큼 댓글 조회 쿼리가 실행됩니다.
- **연관 관계가 중첩된 경우** — `post.member.team.name`과 같이 연관 관계를 단계적으로 탐색하면, 각 단계에서 N+1이 중첩되어 발생할 수 있습니다.

여기서는 지연 로딩(`LAZY`)을 기준으로 설명합니다. 즉시 로딩(`EAGER`)에서는 연관 데이터에 직접 접근하지 않아도 N+1이 발생할 수 있는데, 이에 대해서는 다음 절에서 다룹니다. 정리하면 N+1은 "연관 관계가 존재한다"는 사실 자체가 아니라, **연관 데이터를 별도의 쿼리로 조회하게 되는 구조**에서 발생합니다.

### 왜 발생하나 — LAZY와 프록시

이제 원인을 살펴보겠습니다. 핵심은 연관 관계의 **fetch 전략**에 있습니다. JPA는 연관 객체를 조회하는 시점을 `LAZY`(지연 로딩)와 `EAGER`(즉시 로딩) 두 가지로 구분합니다.

```kotlin
class Post(
    @ManyToOne(fetch = FetchType.LAZY)
    val member: Member,
)
```

`LAZY`로 설정하면 게시글을 조회하는 시점에는 `member`를 실제로 조회하지 않습니다. 대신 그 자리에 **프록시(proxy) 객체** 를 할당해 두고, `post.member.name`과 같이 실제 값에 처음 접근하는 시점에 `SELECT ... FROM member WHERE id = ?` 쿼리를 실행합니다. 따라서 서로 다른 작성자를 가진 게시글 100개를 반복문으로 순회하며 작성자 이름을 조회하면, 접근할 때마다 쿼리가 한 번씩 실행되어 최대 100번의 추가 쿼리가 발생합니다.

이쯤에서 흔히 나오는 의문이 있습니다. "그럼 `EAGER`로 바꾸면 되지 않나?"

`EAGER`로 변경한다고 N+1이 해결되지는 않습니다. `EAGER`는 "연관 객체를 **즉시 조회한다**"는 요구일 뿐, "**하나의 쿼리로 조인하여 조회한다**"는 의미가 아니기 때문입니다. 즉시 로딩을 조인으로 처리할지 별도 SELECT로 처리할지는 구현체와 조회 방법에 따라 다릅니다. 특히 `findAll()`처럼 JPQL 기반의 목록 조회에서는, Hibernate가 EAGER 연관 관계를 보통 별도 SELECT로 로딩하므로 N+1이 그대로 발생할 수 있습니다. 게다가 `LAZY`와 달리 작성자 이름을 사용하지 않아도 조회 직후 곧바로 추가 쿼리가 실행되며, 해당 엔티티를 조회하는 모든 경우에 연관 객체가 함께 조회됩니다. 이런 이유로 연관 관계는 일반적으로 `LAZY`로 두는 것이 권장됩니다. (참고로 `@ManyToOne`·`@OneToOne`의 기본 전략은 `EAGER`, `@OneToMany`·`@ManyToMany`는 `LAZY`입니다.)

정리하면, N+1은 **`LAZY`든 `EAGER`든 "연관 데이터를 별도 쿼리로 조회하게 되는 구조"** 에서 발생하는 문제입니다. fetch 전략을 바꾸는 것이 아니라, **연관 데이터를 최초 조회에서 함께 가져오도록** 쿼리 자체를 바꿔야 해결됩니다. 다음 절에서 살펴볼 세 가지 방식이 바로 이 역할을 합니다. (배치 조회처럼 다른 접근도 있으며, 이는 뒤에서 짧게 언급합니다.)

## 한눈에 비교

연관 데이터를 하나의 쿼리로 조인하여 조회하는 방법은 크게 세 가지입니다. **`@EntityGraph`**, **JPQL의 fetch join**, **QueryDSL**입니다. 세 방법 모두 목표는 동일하지만 작성 방식과 안전성이 다릅니다. 먼저 전체를 비교한 뒤, 각각을 살펴보겠습니다.

| 방식 | 성격 | 검증 시점 | 타입 안전성 | 동적 조건 작성 |
|------|------|----------|------------|----------------|
| **@EntityGraph** | 로딩 계획 지정 | 런타임 (메서드 호출 시) | 낮음 | 해당 없음 |
| **JPQL** | 쿼리 작성 | 애플리케이션 시작 시 | 중간 | 불가 |
| **QueryDSL** | 쿼리 작성 | 컴파일 타임 | 높음 | 가능 |

한 가지 짚어둘 점은, **`@EntityGraph`는 JPQL·QueryDSL과 정확히 같은 종류의 도구가 아니라는 것**입니다. `@EntityGraph`는 조회 조건을 작성하는 쿼리 언어가 아니라, 어떤 연관 엔티티를 함께 로딩할지 **로딩 계획**을 지정하는 기능입니다. 반면 JPQL과 QueryDSL은 쿼리 자체를 작성하는 방식입니다. 그래서 동적 조건 작성은 `@EntityGraph`에는 해당하지 않습니다.

검증 시점 측면에서 가장 큰 차이는 **속성명에 오타가 있을 때 그 오류가 언제 발견되느냐**입니다. QueryDSL은 컴파일 단계에서 빌드가 실패하고, JPQL은 애플리케이션이 시작될 때 부팅이 실패하며, `@EntityGraph`는 그 메서드를 실제로 호출하기 전까지 오류를 발견하지 못합니다.

---

## 1. @EntityGraph

Spring Data JPA의 메서드 쿼리에 어노테이션을 추가하는 방식입니다.

```kotlin
@EntityGraph(attributePaths = ["member"])
fun findByIsPublishedTrue(): List<Post>

// 여러 연관 관계도 한 번에
@EntityGraph(attributePaths = ["member", "category", "tags"])
fun findDetailById(id: Long): Post?
```

### 특징

- 메서드 쿼리와 조합하여 사용할 수 있다
- 선언적이고 간결하다
- **속성명을 문자열로 지정하므로 검증 시점이 가장 늦다.** `"member"`를 `"memer"`로 잘못 입력하면 빌드는 통과하고, 일반적으로 해당 메서드를 호출하는 시점에 오류가 발생한다

### 적합한 경우

- 단순 조회에 fetch join만 추가하는 경우
- 기존 메서드 쿼리에 연관 로딩만 추가하는 경우

### 적합하지 않은 경우

- 복잡한 조건이 필요한 경우
- 동적 쿼리가 필요한 경우
- 컴파일 시점의 정적 검증이 중요한 경우

---

## 2. JPQL (fetch join)

`@Query`에 직접 JPQL을 작성하는 방식입니다.

```kotlin
@Query("""
    SELECT DISTINCT p FROM Post p
    LEFT JOIN FETCH p.member
    LEFT JOIN FETCH p.comments
    WHERE p.isPublished = true
""")
fun findPublishedWithComments(): List<Post>
```

위 예시처럼 컬렉션(`p.comments`)을 fetch join하면 조인 결과만큼 행이 늘어나 같은 게시글이 중복으로 조회될 수 있습니다. Hibernate 5 이하에서는 이를 제거하기 위해 `SELECT DISTINCT`를 사용했지만, **Hibernate 6(Spring Boot 3)부터는 엔티티 조회 결과의 중복이 자동으로 제거되므로 `DISTINCT`가 필수는 아닙니다.**

### 특징

- SQL과 유사한 문법이라 가독성이 높다
- **애플리케이션 시작 시 쿼리를 파싱한다.** 문법 오류나 잘못된 속성명이 있으면 부팅 단계에서 오류가 발생한다
- 복잡한 정적 조건을 표현하기 적합하다

### 적합한 경우

정적인 조건이라면 복잡한 조인도 비교적 명확하게 표현할 수 있습니다.

```kotlin
@Query("""
    SELECT p FROM Post p
    LEFT JOIN FETCH p.member
    WHERE p.category.id = :categoryId
    AND p.status IN :statuses
""")
fun findByCategoryAndStatuses(categoryId: Long, statuses: List<PostStatus>): List<Post>
```

참고로 JPQL은 `@Modifying`과 함께 대량 변경(bulk update/delete) 쿼리에도 간결하게 쓰이지만, 이는 N+1 해결과는 별개의 장점입니다.

### 적합하지 않은 경우

- 조건이 런타임에 결정되는 동적 쿼리
- 컴파일 시점의 정적 검증이 중요한 경우

---

## 3. QueryDSL

Q클래스를 기반으로 코드를 통해 쿼리를 작성하는 방식입니다.

```kotlin
fun findPostWithMember(postId: Long): Post? {
    return queryFactory
        .selectFrom(post)
        .leftJoin(post.member).fetchJoin()
        .leftJoin(post.category).fetchJoin()
        .where(post.id.eq(postId))
        .fetchOne()
}
```

### 특징

- **Q클래스를 통해 속성명과 타입 오류를 컴파일 시점에 발견할 수 있다.** 다만 생성된 쿼리의 실제 DB 실행 가능성이나 fetch join·페이징 조합 같은 의미적 문제까지 검증하지는 않는다
- 타입 안전한 동적 쿼리를 작성할 수 있다
- IDE 자동완성을 지원한다

### 적합한 경우

동적 쿼리에서 특히 유용합니다. 조건이 `null`이면 해당 조건은 자동으로 제외됩니다.

```kotlin
fun searchPosts(condition: PostSearchCondition): List<Post> {
    return queryFactory
        .selectFrom(post)
        .leftJoin(post.member).fetchJoin()
        .where(
            condition.memberId?.let { post.member.id.eq(it) },
            condition.status?.let { post.status.eq(it) },
            condition.fromDate?.let { post.createdAt.goe(it.atStartOfDay()) }
        )
        .fetch()
}
```

### 적합하지 않은 경우

- 단순 조회 (과도한 설계가 될 수 있다)
- 대량 변경 쿼리 (JPQL이 더 간결하다)

---

## 적용 시 주의사항

세 방식 모두 공통적으로 주의할 점이 있습니다.

- **여러 컬렉션을 동시에 fetch join할 때는 주의해야 한다.** 순서가 없는 `List`(bag) 컬렉션을 둘 이상 함께 fetch join하면 `MultipleBagFetchException`이 발생할 수 있습니다. 이 예외를 피하더라도, 서로 다른 컬렉션을 함께 조인하면 결과가 카테시안 곱(cartesian product)으로 불어나 성능이 크게 저하될 수 있습니다. 보통 한 번에 하나의 컬렉션만 fetch join하고, 나머지는 배치 조회 등으로 분리합니다.
- **컬렉션 fetch join과 페이징을 함께 사용하면 메모리에서 페이징된다.** Hibernate가 조건에 해당하는 모든 행을 조회한 뒤 애플리케이션 메모리에서 페이징을 수행하므로(`firstResult/maxResults specified with collection fetch` 경고), 데이터가 많으면 메모리 부담이 커집니다. 이 경우 ID만 먼저 페이징으로 조회한 뒤 해당 ID로 연관 데이터를 별도로 조회하거나, 배치 조회로 대체할 수 있습니다.
- **이 글에서 다루는 범위.** 여기서는 fetch join 계열의 세 가지 방법에 집중했습니다. 컬렉션 N+1은 `@BatchSize`나 `default_batch_fetch_size` 설정을 통한 배치 조회로 해결하는 방법도 자주 사용되며, 이는 별도로 다룰 주제입니다.

---

## 상황별 선택 기준

| 상황 | 권장 방식 |
|------|----------|
| 단순 조회 + fetch join | `@EntityGraph` |
| 기존 메서드 쿼리에 fetch만 추가 | `@EntityGraph` |
| 복잡한 정적 조건 | JPQL |
| 동적 조건 | QueryDSL |
| 동적 조건 + 페이징 | QueryDSL |
| 컴파일 시점의 정적 검증이 중요한 경우 | QueryDSL |
| 컬렉션 로딩 + 페이징 | fetch join 대신 ID 페이징 후 재조회 또는 배치 조회 |

페이징은 한 가지 주의가 필요합니다. **동적 조건 + 페이징**은 QueryDSL이 잘 맞지만, **컬렉션을 함께 로딩하면서 페이징**해야 한다면 어떤 도구를 쓰든 fetch join + 페이징 조합은 피하는 편이 좋습니다(앞의 "적용 시 주의사항"에서 설명한 메모리 페이징 문제). 이 경우 ID만 먼저 페이징으로 조회한 뒤 해당 ID로 연관 데이터를 다시 조회하거나, 배치 조회로 분리합니다.

세 방식은 경쟁 관계가 아니라 상황에 따라 선택하는 도구에 가깝습니다. 단순한 조회는 `@EntityGraph`로, 검색 조건이 많은 경우는 QueryDSL로, 정적이지만 복잡한 조건은 JPQL로 처리하는 조합을 고려할 수 있습니다.

## 정리

- N+1은 연관 데이터를 별도의 쿼리로 조회하게 되는 구조에서 발생하며, fetch 전략(`LAZY`/`EAGER`)을 바꾸는 것만으로는 해결되지 않는다
- 이 글에서 다룬 세 방식의 핵심은 최초 조회 시점에 연관 데이터를 함께 가져오는 것이다 (이 외에 배치 조회 같은 접근도 있다)
- `@EntityGraph`는 간결하지만 검증 시점이 가장 늦고, JPQL은 부팅 시점에 검증되며, QueryDSL은 속성명·타입 오류를 컴파일 시점에 잡아내고 동적 조건 작성에 적합하다

프로젝트의 쿼리 복잡도와 요구되는 안전성 수준에 맞추어 선택하면 됩니다.
