---
title: 'VARCHAR 정의 길이가 성능에 영향을 주는 경계는 255자가 아니다'
description: '컬럼 길이를 100자에서 1000자로 늘려 달라는 요청에 "255자를 넘기면 성능이 달라진다"는 말이 나왔습니다. MariaDB 11.4에서 확인해 보니 255는 글자가 아니라 바이트 경계였고, 실행 시간에 영향을 주는 선은 메모리 임시 테이블이 감당하는 512자에 있었습니다.'
pubDate: 'Sep 16 2026'
tags: ['데이터베이스', 'MariaDB', 'MySQL', 'SQL']
category: 'database'
draft: false
---

제가 맡은 테이블에 직접입력 설명을 담는 컬럼이 있었습니다. 100자로 잡아 둔 것을 1000자로 늘려 달라는 요청이 왔습니다.

길이를 바꾸는 것뿐이라 그대로 올리려는데, "255자를 넘기면 성능이 달라진다고 기억하는데"라는 말이 나왔습니다. 그 자리에서 근거를 대는 사람은 없었습니다. 길이를 100자로 둘지 1000자로 늘릴지가 이 숫자에 걸려 있었습니다.

MariaDB 11.4.2에서 확인한 결과를 정리합니다. 결론부터 적으면, 255는 글자가 아니라 바이트 단위의 수이고 저장 크기에만 관계합니다. 정의 길이가 실행 시간에 영향을 주는 자리는 따로 있었습니다. 내부 임시 테이블이고, 그 경계는 512자였습니다.

## VARCHAR의 255는 글자 수가 아니라 바이트 수

MySQL 매뉴얼은 VARCHAR 저장 방식을 이렇게 설명합니다. VARCHAR 값은 1바이트 또는 2바이트 길이 프리픽스와 데이터로 저장됩니다. 길이 프리픽스는 값의 바이트 수를 나타냅니다. 값이 255바이트를 넘지 않으면 길이 바이트 하나를, 255바이트를 넘을 수 있으면 두 개를 씁니다.

기준은 바이트입니다. 글자가 아닙니다.

한 글자가 몇 바이트인지는 문자셋이 정합니다. latin1은 한 글자가 1바이트입니다. `VARCHAR(255)`는 최대 255바이트라 길이 프리픽스가 1바이트이고, `VARCHAR(256)`은 최대 256바이트라 2바이트가 됩니다. 여기서는 255라는 숫자가 글자 수와 맞아떨어집니다.

utf8mb4는 한 글자가 최대 4바이트입니다. `VARCHAR(63)`은 최대 252바이트, `VARCHAR(64)`는 최대 256바이트입니다. 경계가 63자와 64자 사이에 있습니다. utf8mb4를 쓰는 컬럼에서 255자는 길이 프리픽스와 관계가 없습니다.

## utf8mb4에서 프리픽스가 2바이트로 늘어나는 지점은 64자

매뉴얼 설명이 맞는지는 행 크기로 확인할 수 있습니다. 매뉴얼은 한 테이블의 행 크기 상한을 65,535바이트로 두고, 가변 길이 컬럼의 길이 바이트도 이 합계에 포함한다고 적고 있습니다. 상한을 넘기면 `CREATE TABLE`이 실패합니다.

```
ERROR 1118 (42000): Row size too large.
```

그래서 컬럼 두 개짜리 테이블을 만들었습니다. 앞 컬럼 `a`는 utf8mb4 `VARCHAR(N)`으로, 뒤 컬럼 `b`는 latin1 `VARCHAR(M)`으로 뒀습니다. `N`을 하나씩 올리면서 `CREATE TABLE`이 성공하는 `M`의 최댓값을 이분 탐색으로 찾았습니다. `b`를 latin1로 둔 이유는 한 글자가 1바이트라 남은 예산이 1바이트 단위로 보이기 때문입니다.

`a`가 utf8mb4일 때의 결과입니다.

| `a`의 정의 길이 | `b`의 최댓값 | 앞 행 대비 감소 |
|---|---|---|
| VARCHAR(61) | 65,287 | |
| VARCHAR(62) | 65,283 | 4 |
| VARCHAR(63) | 65,279 | 4 |
| VARCHAR(64) | 65,274 | **5** |
| VARCHAR(65) | 65,270 | 4 |
| VARCHAR(66) | 65,266 | 4 |
| VARCHAR(254) | 64,514 | |
| VARCHAR(255) | 64,510 | 4 |
| VARCHAR(256) | 64,506 | 4 |

`a`를 한 글자 늘리면 데이터 영역이 4바이트 늘어납니다. 63자에서 64자로 갈 때만 5바이트가 줄어듭니다. 남는 1바이트가 길이 프리픽스입니다. 255자 근처에서는 4바이트씩만 줄어듭니다.

같은 측정을 `a`도 latin1로 두고 돌렸습니다.

| `a`의 정의 길이 | `b`의 최댓값 | 앞 행 대비 감소 |
|---|---|---|
| VARCHAR(253) | 65,278 | |
| VARCHAR(254) | 65,277 | 1 |
| VARCHAR(255) | 65,276 | 1 |
| VARCHAR(256) | 65,274 | **2** |
| VARCHAR(257) | 65,273 | 1 |

이번에는 255자에서 256자로 갈 때 계단이 생깁니다. 두 결과를 겹쳐 놓으면 경계가 글자 수가 아니라 바이트 수에 있다는 점이 드러납니다. 최대 바이트 길이가 255를 넘는 순간 프리픽스가 1바이트 늘어납니다.

## 정의 길이를 늘려도 테이블 크기는 그대로임

프리픽스는 한두 바이트 문제입니다. 20만 행이면 20만 바이트, 0.2MB 차이입니다. 정의 길이를 100자에서 1000자로 늘리면 저장 크기가 얼마나 커지는지가 더 궁금했습니다.

정의 길이만 다른 테이블 네 개를 만들고 같은 데이터를 넣었습니다. 20만 행이고 모든 값이 44자 48바이트입니다.

| 테이블 | 정의 길이 | `data_length` |
|---|---|---|
| t63 | VARCHAR(63) | 16,269,312 |
| t100 | VARCHAR(100) | 16,269,312 |
| t255 | VARCHAR(255) | 16,269,312 |
| t1000 | VARCHAR(1000) | 16,269,312 |

네 테이블이 같습니다. InnoDB는 값을 실제 길이만큼 저장하므로 정의 길이는 저장 크기에 들어가지 않습니다.

`data_length`는 16KB 페이지 단위로 집계됩니다. 16,269,312는 16,384에 993을 곱한 값입니다. t63과 나머지 세 테이블은 길이 프리픽스가 1바이트와 2바이트로 갈립니다. 다만 20만 행에서 0.2MB인 차이라 페이지 단위 수치에는 드러나지 않습니다. 정의 길이를 열 배로 늘려도 디스크에서 달라지는 것은 없습니다.

## 그러면 255자를 넘기면 느려진다는 말은 어디서 왔을까?

저장 크기가 같다면 남는 것은 실행 시간입니다. 정의 길이가 실행 시간에 들어오는 자리는 서버가 내부 임시 테이블을 만들 때입니다.

`GROUP BY`, `ORDER BY`, `DISTINCT`, `UNION`, 파생 테이블은 중간 결과를 담을 테이블을 필요로 합니다. 서버는 이 테이블을 먼저 메모리에 만들고, 크기가 한도를 넘으면 디스크에 다시 만듭니다. 디스크로 옮겨지면 읽고 쓰는 비용이 달라집니다.

메모리 임시 테이블이 정의 길이를 어떻게 다루는지가 여기서 갈립니다.

## 메모리 임시 테이블은 VARCHAR를 정의 길이만큼 채워 넣음

MySQL 매뉴얼은 MEMORY 엔진이 관리하는 메모리 내부 임시 테이블에 고정 길이 행 형식이 쓰인다고 적습니다. VARCHAR와 VARBINARY 값은 컬럼 최대 길이까지 패딩되어 CHAR, BINARY처럼 저장됩니다.

값이 48바이트여도 컬럼이 utf8mb4 `VARCHAR(1000)`이면 한 행이 4,000바이트를 차지합니다. `VARCHAR(100)`이면 400바이트입니다. 열 배 차이입니다.

메모리 임시 테이블의 크기 한도는 `tmp_table_size`와 `max_heap_table_size` 중 작은 값입니다. 제 환경에서는 둘 다 기본값이 16,777,216바이트(16MB)였습니다. 한도를 넘으면 서버가 테이블을 디스크에 다시 만듭니다. MariaDB는 디스크 임시 테이블에 Aria 엔진을 씁니다(`aria_used_for_temp_tables`의 기본값이 ON).

디스크로 넘어갔는지는 `Created_tmp_disk_tables` 상태 변수로 셀 수 있습니다.

## 정의 길이가 길수록 디스크 임시 테이블로 더 빨리 넘어감

앞에서 만든 네 테이블에 같은 모양의 쿼리를 돌렸습니다.

```sql
FLUSH STATUS;
SELECT COUNT(*) FROM (SELECT v, COUNT(*) FROM t100 GROUP BY v) x;
SHOW STATUS LIKE 'Created_tmp_disk_tables';
```

`tmp_table_size`와 `max_heap_table_size`를 같이 올려 가며, 디스크로 넘어가지 않는 최소 크기를 찾았습니다.

| 테이블 | 정의 길이 | 디스크로 넘어감 | 넘어가지 않음 | 정의 길이 × 4바이트 × 20만 행 |
|---|---|---|---|---|
| t63 | VARCHAR(63) | 48MB | 64MB | 50.4MB |
| t100 | VARCHAR(100) | 64MB | 96MB | 80MB |
| t255 | VARCHAR(255) | 200MB | 208MB | 204MB |
| t1000 | VARCHAR(1000) | 1,024MB | 찾지 못함 | 800MB |

앞의 세 테이블은 정의 길이에 문자셋 최대 바이트와 행 수를 곱한 값 근처에서 경계가 잡힙니다. 메모리 임시 테이블이 정의 길이만큼 자리를 잡아 둔다는 매뉴얼 설명과 맞습니다.

여기에 255는 없습니다. 63자든 255자든 같은 방식으로 늘어날 뿐입니다. 기본값 16MB에서는 네 테이블 모두 디스크로 넘어갑니다.

t1000만 다릅니다.

## 메모리 임시 테이블을 쓸 수 있는 정의 길이 상한은 512자

t1000은 한도를 2,048MB로 올려도 메모리에 남지 않았습니다. 800MB면 들어갈 크기인데 그렇지 않습니다. 크기와 다른 조건이 걸려 있습니다.

행 수를 2만으로 줄이고 한도를 2,048MB로 고정한 뒤, 정의 길이만 바꿔 가며 다시 쟀습니다.

| 정의 길이 (utf8mb4) | 디스크 임시 테이블 |
|---|---|
| VARCHAR(500) | 만들어지지 않음 |
| VARCHAR(510) | 만들어지지 않음 |
| VARCHAR(512) | 만들어지지 않음 |
| VARCHAR(513) | 만들어짐 |
| VARCHAR(520) | 만들어짐 |
| VARCHAR(600) | 만들어짐 |

512자와 513자 사이입니다. 바이트로 치면 2,048바이트와 2,052바이트입니다. 이 경계가 바이트인지 글자인지 가르려고 latin1로 같은 측정을 했습니다.

| 정의 길이 (latin1) | 디스크 임시 테이블 |
|---|---|
| VARCHAR(512) | 만들어지지 않음 |
| VARCHAR(513) | 만들어짐 |
| VARCHAR(2048) | 만들어짐 |
| VARCHAR(2049) | 만들어짐 |

latin1도 512자에서 갈립니다. 2,048바이트가 기준이었다면 latin1 `VARCHAR(2048)`이 메모리에 남았어야 합니다. 기준은 글자 수입니다.

MariaDB 소스에 같은 숫자가 있습니다.

```c
/* Threshold for when to convert a large VARCHAR to a BLOB */
#define CONVERT_IF_BIGGER_TO_BLOB 512   /* Threshold *in characters* */
```

이 값을 쓰는 곳은 `Item::too_big_for_varchar()`입니다.

```cpp
bool too_big_for_varchar() const
{ return max_char_length() > CONVERT_IF_BIGGER_TO_BLOB; }
```

정의 길이가 512자를 넘는 문자열 컬럼은 임시 테이블에서 BLOB으로 만들어집니다. 그리고 MEMORY 엔진은 BLOB을 담지 못합니다.

```
ERROR 1163 (42000): Storage engine MEMORY doesn't support BLOB/TEXT columns
```

512자를 넘는 컬럼이 임시 테이블에 들어가면 한도를 얼마로 잡든 디스크로 갑니다. 100자를 1000자로 늘려 달라는 요청은 이 선을 넘는 변경이었습니다.

## MySQL 8.0의 TempTable 엔진은 정의 길이만큼 채우지 않음

여기까지는 MariaDB 11.4 이야기입니다. MySQL 8.0부터는 메모리 내부 임시 테이블의 기본 엔진이 MEMORY가 아니라 TempTable입니다. `internal_tmp_mem_storage_engine`의 기본값이 `TempTable`입니다.

MySQL 매뉴얼은 TempTable이 VARCHAR를 다루는 방식을 이렇게 설명합니다. VARCHAR 컬럼이 있는 행은 셀 배열로 표현되고, 각 셀은 NULL 플래그와 데이터 길이와 데이터 포인터를 담습니다. 컬럼 값은 배열 뒤에 패딩 없이 이어 붙습니다.

패딩이 없으면 정의 길이가 메모리 임시 테이블 크기에 들어가지 않습니다. MySQL 8.0 이상에서는 앞의 측정이 같은 모양으로 나오지 않을 것으로 보입니다.

다만 이것은 매뉴얼 서술이고, MySQL 서버를 띄워 확인하지는 않았습니다. 여기 적은 측정값은 전부 MariaDB 11.4.2에서 나온 것입니다. MariaDB 11.4에는 `internal_tmp_mem_storage_engine` 변수가 없습니다.

## 그래서 길이를 얼마로 잡아야 할까?

정의 길이를 정할 때 확인할 것은 네 가지입니다.

**저장 크기는 근거가 되지 않습니다:** InnoDB는 값을 실제 길이만큼 저장합니다. 정의 길이를 넉넉하게 잡는다고 디스크가 늘지 않습니다.

**메모리 임시 테이블을 쓰려면 512자 아래여야 합니다:** MariaDB에서 정의 길이가 512자를 넘으면 그 컬럼이 들어간 임시 테이블은 디스크로 갑니다. `tmp_table_size`를 올려도 달라지지 않습니다.

**512자 아래에서도 정의 길이에 문자셋 최대 바이트와 행 수를 곱한 값이 한도 안에 들어와야 합니다:** utf8mb4 `VARCHAR(255)` 컬럼 20만 행을 묶는 쿼리는 한도가 200MB여도 디스크로 넘어갔습니다. 기본값 16MB는 훨씬 작습니다.

**인덱스를 걸 컬럼이면 키 길이 상한이 따로 있습니다:** 제 환경의 InnoDB는 utf8mb4 `VARCHAR(768)`까지 인덱스를 만들고 769자부터는 거부했습니다. 3,072바이트가 상한입니다.

그래서 100자를 1000자로 늘리는 변경은 한 가지를 확인하면 됩니다. 그 컬럼이 임시 테이블을 만드는 쿼리의 중간 결과에 들어가는지입니다. 들어가지 않으면 길이를 늘려도 여기서 잰 비용은 생기지 않습니다. 들어가면 512자를 넘기는 순간 그 쿼리는 디스크 임시 테이블을 쓰게 됩니다.

## 마치며

255라는 숫자는 실재합니다. 다만 그것은 길이 프리픽스가 1바이트에서 2바이트로 늘어나는 바이트 경계이고, 20만 행에서 0.2MB를 좌우합니다. utf8mb4에서 그 자리는 64자입니다.

실행 시간에 영향을 주는 경계는 512자였습니다. 메모리 임시 테이블이 그 위로는 만들어지지 않기 때문입니다.

컬럼 길이를 정하는 기준으로 255를 쓸 근거는 이번 측정에서 찾지 못했습니다.

## 부록. 측정에 쓴 테이블과 쿼리

데이터 준비입니다.

```sql
SET SESSION max_recursive_iterations = 300000;
CREATE DATABASE vbench CHARACTER SET utf8mb4;
USE vbench;

CREATE TABLE src (id INT PRIMARY KEY, v VARCHAR(63) CHARACTER SET utf8mb4);
INSERT INTO src
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 200000)
SELECT n, CONCAT('메모-', LPAD(n, 8, '0'), '-', MD5(n)) FROM seq;

CREATE TABLE t63   (id INT PRIMARY KEY, v VARCHAR(63)   CHARACTER SET utf8mb4);
CREATE TABLE t100  (id INT PRIMARY KEY, v VARCHAR(100)  CHARACTER SET utf8mb4);
CREATE TABLE t255  (id INT PRIMARY KEY, v VARCHAR(255)  CHARACTER SET utf8mb4);
CREATE TABLE t1000 (id INT PRIMARY KEY, v VARCHAR(1000) CHARACTER SET utf8mb4);

INSERT INTO t63   SELECT * FROM src;
INSERT INTO t100  SELECT * FROM src;
INSERT INTO t255  SELECT * FROM src;
INSERT INTO t1000 SELECT * FROM src;
ANALYZE TABLE t63, t100, t255, t1000;
```

행 크기 예산 측정입니다. `b`의 길이를 이분 탐색으로 올리고 내리면서 `CREATE TABLE`이 성공하는 최댓값을 찾았습니다.

```sql
CREATE TABLE zz (
  a VARCHAR(64)    CHARACTER SET utf8mb4,
  b VARCHAR(65274) CHARACTER SET latin1
);
```

디스크 임시 테이블 측정입니다. 한도를 바꿔 가며 반복했습니다.

```sql
SET SESSION max_heap_table_size = 64*1024*1024;
SET SESSION tmp_table_size      = 64*1024*1024;
FLUSH STATUS;
SELECT COUNT(*) FROM (SELECT v, COUNT(*) FROM t100 GROUP BY v) x;
SHOW STATUS LIKE 'Created_tmp_disk_tables';
```

측정 환경은 MariaDB 11.4.2, macOS, InnoDB, `innodb_page_size` 16384, 기본 문자셋 utf8mb4입니다.

## 참고 문헌

- [MySQL 8.4 Reference Manual: The CHAR and VARCHAR Types](https://dev.mysql.com/doc/refman/8.4/en/char.html): VARCHAR가 1바이트 또는 2바이트 길이 프리픽스와 데이터로 저장되며 그 경계가 255바이트라고 설명합니다.
- [MySQL 8.4 Reference Manual: Limits on Table Column Count and Row Size](https://dev.mysql.com/doc/refman/8.4/en/column-count-limit.html): 행 크기 상한 65,535바이트와, 가변 길이 컬럼의 길이 바이트가 이 합계에 포함된다는 점을 다룹니다.
- [MySQL 8.4 Reference Manual: Internal Temporary Table Use in MySQL](https://dev.mysql.com/doc/refman/8.4/en/internal-temporary-tables.html): MEMORY 엔진의 고정 길이 행 형식과 TempTable 엔진의 VARCHAR 저장 방식을 나란히 설명합니다.
- [MariaDB Knowledge Base: Aria System Variables](https://mariadb.com/kb/en/aria-system-variables/): `aria_used_for_temp_tables`의 뜻과 기본값이 ON이라는 점을 적고 있습니다.
- [MariaDB Server: sql/sql_const.h](https://github.com/MariaDB/server/blob/main/sql/sql_const.h): `CONVERT_IF_BIGGER_TO_BLOB`을 512로 정의하고 단위가 글자 수라는 주석을 달아 두었습니다.
- [MariaDB Server: sql/item.h](https://github.com/MariaDB/server/blob/main/sql/item.h): `Item::too_big_for_varchar()`가 이 상수를 최대 글자 수와 비교하는 부분입니다.
