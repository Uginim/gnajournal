---
title: 'MySQL 공간 데이터(위치 정보)를 JPA로 다루기'
description: 'MySQL 공간 타입(POINT)을 Spring Data JPA와 Hibernate Spatial로 저장하고 반경 검색하는 기본기를 정리합니다. SRID 4326, 좌표 축 순서, ST_Distance_Sphere.'
pubDate: 'Jul 23 2026'
heroImage: '../../assets/blog-placeholder-3.jpg'
tags: ['MySQL', 'JPA', 'Hibernate', '공간데이터']
draft: true
---

"내 위치에서 반경 1km 안의 가게 찾기" 같은 기능을 만들려면, 위도와 경도를 단순히 `DOUBLE` 두 개로 저장하기보다 데이터베이스의 공간(spatial) 타입을 쓰는 편이 낫습니다. 공간 인덱스를 태우고, DB가 제공하는 거리 계산 함수를 그대로 쓸 수 있기 때문입니다. 이 글은 MySQL의 공간 타입을 Spring Data JPA(Hibernate)로 저장하고 조회하는 기본기를 정리합니다.

## MySQL의 공간 타입

MySQL은 `GEOMETRY`를 최상위로 하는 공간 타입군을 지원합니다. 위치 한 점을 저장할 때 쓰는 타입은 `POINT`입니다.

```sql
CREATE TABLE store (
    id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    location POINT NOT NULL SRID 4326,      -- 위치(위도, 경도)
    SPATIAL INDEX idx_store_location (location)
);
```

SRID와 공간 인덱스, 두 가지를 신경 써야 합니다.

- **SRID 4326**: 우리가 흔히 쓰는 GPS 좌표계(WGS84)의 식별자입니다. 위도와 경도를 다룬다면 4326을 명시하는 것이 좋습니다. SRID를 컬럼에 고정해야 공간 인덱스와 거리 함수가 의도대로 동작합니다.
- **SPATIAL INDEX**: 공간 검색을 빠르게 하려면 필수입니다. 단, MySQL(InnoDB)에서 공간 인덱스를 걸려면 해당 컬럼이 `NOT NULL`이어야 합니다.

> 좌표 축 순서에 주의해야 합니다. SRID 4326에서 MySQL은 좌표를 (위도 latitude, 경도 longitude) 순서로 해석합니다. 반면 많은 라이브러리와 GeoJSON은 (경도, 위도) 순서를 씁니다. 이 축 순서 불일치가 거리가 이상하게 나오는 버그의 단골 원인입니다. 저장과 조회 양쪽에서 순서를 통일해야 합니다.

## 의존성 추가 (Hibernate Spatial)

JPA에서 공간 타입을 자바 객체로 매핑하려면 hibernate-spatial이 필요합니다. Hibernate 6에서는 이 의존성만 추가하면 공간 타입이 자동으로 인식됩니다.

```gradle
// build.gradle
implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
implementation 'org.hibernate.orm:hibernate-spatial:6.4.4.Final'  // 사용 중인 Hibernate 버전에 맞춤
runtimeOnly    'com.mysql:mysql-connector-j'
```

`hibernate-spatial`은 내부적으로 JTS(Java Topology Suite)의 지오메트리 타입을 가져옵니다. 엔티티 필드는 이 JTS 타입으로 선언합니다.

## 엔티티 매핑

필드 타입으로 `org.locationtech.jts.geom.Point`를 그대로 씁니다.

```java
import jakarta.persistence.*;
import org.locationtech.jts.geom.Point;

@Entity
public class Store {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Column(columnDefinition = "POINT SRID 4326", nullable = false)
    private Point location;

    // getter/setter
}
```

`columnDefinition`으로 컬럼 타입과 SRID를 고정해 두면, DDL 자동 생성 때도 스키마가 의도대로 만들어집니다.

## Point 만들어 저장하기

JTS의 `GeometryFactory`로 `Point` 객체를 만듭니다. `Coordinate`에 넣는 값과 SRID를 반드시 맞춰야 합니다.

```java
import org.locationtech.jts.geom.*;

@Service
@RequiredArgsConstructor
public class StoreService {

    private final StoreRepository storeRepository;

    // GeometryFactory는 SRID 4326으로 한 번 만들어 재사용
    private final GeometryFactory geometryFactory =
            new GeometryFactory(new PrecisionModel(), 4326);

    public Store save(String name, double latitude, double longitude) {
        // MySQL SRID 4326의 축 순서에 맞춰 (위도, 경도)로 좌표 구성
        Point point = geometryFactory.createPoint(new Coordinate(latitude, longitude));
        point.setSRID(4326);

        Store store = new Store();
        store.setName(name);
        store.setLocation(point);
        return storeRepository.save(store);
    }
}
```

`Coordinate(x, y)`에서 어떤 값을 x로 넣을지는 앞에서 말한 축 순서와 직결됩니다. MySQL 4326 기준이면 x를 위도로 맞추고, 조회 함수에 넘길 기준점도 같은 순서로 만들어야 합니다. 프로젝트 초기에 이 규칙을 한 번 정해 문서로 남겨 두면 편합니다.

## 반경 검색으로 조회하기

특정 좌표에서 일정 거리 안의 데이터를 찾는 쿼리입니다. MySQL의 `ST_Distance_Sphere`는 두 지점 사이 거리를 미터 단위로 반환하므로 반경 검색에 편합니다. 네이티브 쿼리로 작성한 예입니다.

```java
public interface StoreRepository extends JpaRepository<Store, Long> {

    @Query(value = """
        SELECT *,
               ST_Distance_Sphere(location, ST_SRID(POINT(:lat, :lng), 4326)) AS distance
        FROM   store
        WHERE  ST_Distance_Sphere(location, ST_SRID(POINT(:lat, :lng), 4326)) <= :radiusMeters
        ORDER  BY distance
        """, nativeQuery = true)
    List<Store> findWithinRadius(@Param("lat") double lat,
                                 @Param("lng") double lng,
                                 @Param("radiusMeters") double radiusMeters);
}
```

`POINT(:lat, :lng)`에 넘기는 값의 순서도 저장 때와 같아야 합니다. 저장은 (위도, 경도)로 해 놓고 조회는 (경도, 위도)로 넘기면 엉뚱한 곳을 검색하게 됩니다.

Hibernate Spatial을 쓰면 JPQL이나 Criteria에서 `distance()` 같은 공간 함수를 쓸 수도 있습니다. 다만 처음에는 위처럼 네이티브 쿼리와 MySQL 내장 함수로 시작하는 편이 동작을 이해하기에 명확합니다.

## 자주 만나는 함정

- **좌표 축 순서**: SRID 4326에서 MySQL은 (위도, 경도)입니다. 저장, 조회, 기준점 생성 모두 순서를 통일해야 합니다. 거리 오류의 첫 번째 원인입니다.
- **SRID 불일치**: 컬럼은 SRID 4326인데 저장하는 Point의 SRID가 0이면 함수 호출에서 `SRID mismatch` 오류가 납니다. `setSRID(4326)`을 빠뜨리지 않아야 합니다.
- **공간 인덱스와 NOT NULL**: InnoDB 공간 인덱스는 컬럼이 `NOT NULL`이어야 합니다.
- **컬럼 타입 매핑 오류**: 의존성(hibernate-spatial)이 빠지면 `wrong column type 'geometry'` 류의 매핑 오류가 납니다. 의존성부터 확인합니다.
- **거리 단위**: `ST_Distance_Sphere`는 미터, `ST_Distance`는 좌표계에 따라 단위가 달라집니다. 반경 검색에는 `ST_Distance_Sphere`가 직관적입니다.

## 정리

MySQL 공간 데이터를 JPA로 다루는 흐름은 세 줄로 요약됩니다.

1. 컬럼은 `POINT ... SRID 4326`과 공간 인덱스, 엔티티 필드는 JTS `Point`
2. 저장은 `GeometryFactory`로 Point를 만들되 축 순서와 SRID를 맞추기
3. 조회는 `ST_Distance_Sphere`로 미터 단위 반경 검색

규칙(SRID와 축 순서)을 한 번 정해 두면, 위경도 `DOUBLE` 두 개로 직접 계산하는 것보다 오히려 깔끔합니다. 위치 기반 기능을 만든다면 초반에 이 기초를 잡고 가는 것을 권합니다.

---

*버전에 따라 Hibernate와 의존성 좌표, 방언(dialect) 설정이 조금씩 다릅니다. Hibernate 6에서는 hibernate-spatial 추가만으로 대부분 동작하지만, 5.x 이하에서는 별도 Spatial Dialect 지정이 필요할 수 있습니다.*
