---
title: 'collation이 뭐길래 조인만 실패할까?'
description: '이력 테이블을 코드 테이블과 조인하지 못해 데이터팀 작업이 막혔습니다. 원인은 collation 불일치였습니다. collation이 문자 집합과 무엇이 다른지, 왜 컬럼끼리 비교할 때만 Illegal mix of collations가 나는지, 그리고 한국어와 코드 값을 다루는 곳에서 utf8mb4_general_ci를 컨벤션으로 두면 무엇이 나은지 정리했습니다.'
pubDate: 'Aug 25 2026'
tags: ['데이터베이스', 'MariaDB', 'MySQL', 'SQL', 'Liquibase']
category: 'database'
draft: false
---

데이터팀에서 문의가 하나 왔습니다.

> 이력 테이블의 문자열 컬럼만 collation이 `utf8mb4_unicode_ci`로 되어 있는데 왜 그런가요. 코드 테이블이랑 조인이 안 붙습니다.

그 조인이 오류를 내고 있었으니 데이터팀 쪽 작업이 막혀 있었습니다.

문의를 보낸 쪽이 이미 원인 후보를 짚어 놓았습니다. 문의는 받았지만 왜 그 테이블만 collation이 다른지를 몰랐습니다.

확인해 보니 정말 collation이 다르다는 오류가 떴습니다. 원본 테이블로는 조인이 되고 이력 테이블로만 오류가 났습니다.

```sql
-- 원본 테이블로 조인. 결과가 나옵니다
SELECT COUNT(*) AS cnt
FROM `order` o
JOIN code_master m
  ON m.code_group = 'channel' AND m.code_value = o.channel;
-- 38018

-- 이력 테이블로 조인. 오류가 납니다
SELECT COUNT(*) AS cnt
FROM order_aud oa
JOIN code_master m
  ON m.code_group = 'channel' AND m.code_value = oa.channel;
-- ERROR 1267 (HY000): Illegal mix of collations
--   (utf8mb4_general_ci,IMPLICIT) and (utf8mb4_unicode_ci,IMPLICIT) for operation '='
```

해결 자체는 컨벤션대로 맞추는 것이었습니다. 어긋난 값을 `general_ci`로 되돌리면 조인은 통과합니다.

궁금함은 그 뒤에 남았습니다. collation이 다르면 문자열 컬럼끼리 조인이 안 될 수 있다는 것은 알고 있었지만, 왜 안 되는지는 몰랐습니다. 컨벤션으로 두고 있던 값이 무엇이 나은지도 따져 본 적이 없었습니다.

> 과거 업무 사례에서 특정 조직이나 시스템을 알아볼 수 있는 이름을 빼고 구조만 남겼습니다. 본문의 테이블명과 컬럼명은 원래 이름이 아니고, 위 문의도 원문이 아니라 요지를 옮긴 것입니다. 조사 환경은 MariaDB 10.6(운영)과 10.11(스테이지, 개발)이고, 애플리케이션은 Kotlin과 Spring Boot 2.7, Hibernate Envers를 씁니다.

## 문자를 저장하는 규칙과 비교하는 규칙은 다름

collation은 문자열을 비교하고 정렬하는 규칙입니다. 문자 집합(charset)과는 층이 다릅니다.

charset은 문자를 바이트로 바꾸는 규칙입니다. `utf8mb4`는 어떤 문자가 어떤 바이트열이 되는지를 정합니다. collation은 그렇게 저장된 값을 놓고 무엇과 무엇을 같다고 볼지, 어떤 순서로 늘어놓을지를 정합니다.

두 층이 갈라져 있는 이유는 같은 문자 집합을 두고도 판단이 하나로 정해지지 않기 때문입니다. `a`와 `A`를 같게 볼지, 독일어 `ß`를 `ss`와 같게 볼지, 전각 `Ａ`를 반각 `A`와 같게 볼지는 언어와 용도마다 다릅니다. 그래서 charset 하나에 collation이 여럿 붙습니다.

이름에도 그 규칙이 드러납니다. `utf8mb4_general_ci`에서 `utf8mb4`는 charset이고 `ci`는 대소문자를 구분하지 않는다는 뜻(case insensitive)입니다.

## collation이 다르다고 조인이 무조건 실패하지는 않음

실패하는 조건이 따로 있습니다.

MySQL과 MariaDB는 비교에 참여하는 값마다 강제성(coercibility) 등급을 매깁니다. 등급이 가장 낮은 쪽의 collation을 씁니다.

| coercibility | 대상 |
|---|---|
| 0 | 명시적 `COLLATE` 절 |
| 1 | collation이 서로 다른 두 문자열을 이어 붙인 결과 |
| 2 | 컬럼, 스토어드 루틴 파라미터, 로컬 변수 |
| 3 | 시스템 상수 (`USER()`, `VERSION()` 같은 함수의 반환값) |
| 4 | 문자열 리터럴 |
| 5 | 숫자나 시간 값 |
| 6 | `NULL`, 또는 `NULL`에서 파생된 식 |

문자열 리터럴은 4입니다. 컬럼은 2입니다. 그래서 리터럴과 컬럼을 비교하면 컬럼 쪽 collation으로 정해집니다. 다음 쿼리는 `order_aud`에서도 아무 문제가 없습니다.

```sql
SELECT COUNT(*) FROM order_aud WHERE channel = 'WEB';
```

문제는 컬럼 대 컬럼입니다. 양쪽 다 2라 우열이 없습니다. charset은 같은데 collation만 다르면 서버가 어느 쪽으로 비교할지 정하지 못하고 오류를 냅니다. 조인 조건이 정확히 그 형태입니다.

데이터팀처럼 스키마를 고칠 수 없는 쪽에서는 쿼리에서 우회할 수 있습니다. 비교하는 두 컬럼 중 한쪽에 `COLLATE`를 붙이면 그쪽이 0이 됩니다. 가장 낮은 등급이라 그 collation으로 비교가 정해지고, 오류도 나지 않습니다.

```sql
SELECT COUNT(*) AS cnt
FROM order_aud oa
JOIN code_master m
  ON m.code_group = 'channel'
 AND m.code_value = oa.channel COLLATE utf8mb4_general_ci;
```

## general_ci와 unicode_ci는 동치로 보는 범위가 다름

둘 다 대소문자를 구분하지 않습니다. 갈리는 것은 그 밖에 무엇을 같다고 보느냐입니다.

MySQL 문서가 기준을 적어 놓았습니다. `utf8mb4_general_ci`는 문자 대 문자의 일대일 비교만 하는 오래된 collation입니다. 확장(expansion), 축약(contraction), ignorable character를 지원하지 않습니다. `utf8mb4_unicode_ci`는 셋을 모두 지원합니다.

확장은 한 글자가 여러 글자의 조합과 같다고 판정되는 경우입니다. 독일어 `ß`가 그런 글자입니다. 독일어 사전 순서에서 `ß`는 `ss`와 같은 자리에 놓입니다. `unicode_ci`는 그 순서를 따라 두 값을 같게 봅니다. 반면 `general_ci`는 글자 하나에 값 하나만 매기므로 `ß`를 `s` 한 글자에 대응시킵니다. 그래서 `general_ci`에서는 `ß = s`가 참이 되고 `ß = ss`는 거짓이 됩니다.

축약은 반대로 여러 코드포인트를 하나의 정렬 단위로 묶는 것입니다. ignorable character는 비교할 때 가중치가 0이라 무시되는 문자입니다.

MariaDB 10.11에서 테스트한 결과입니다.

| 비교 | general_ci | unicode_ci |
|---|---|---|
| `'a' = 'A'` | 참 | 참 |
| `'ss' = 'ß'` | 거짓 | 참 |
| `'ae' = 'æ'` | 거짓 | 거짓 |
| `'A' = 'Ａ'` (전각) | 거짓 | 참 |

```sql
SELECT ('ss' COLLATE utf8mb4_general_ci) = ('ß' COLLATE utf8mb4_general_ci),
       ('ss' COLLATE utf8mb4_unicode_ci) = ('ß' COLLATE utf8mb4_unicode_ci);
-- 0, 1
```

같은 문서가 `general_ci` 쪽 비교가 더 빠르고 약간 덜 정확하다고 적습니다. 어느 쪽이 옳다고 말하기 어렵습니다. 한국어와 영문만 다루면 두 값의 차이를 체감하기도 어렵습니다.

실무에서 이 차이가 드러나는 자리는 유니크 제약입니다. `unicode_ci`는 더 많은 값을 같다고 보므로 중복으로 막히는 범위가 넓습니다. 그래서 바꾸는 방향에 따라 반대 방향의 사고가 납니다. `general_ci`로 바꾸면 그동안 중복으로 막히던 값이 통과하고, `unicode_ci`로 바꾸면 기존 데이터가 중복 위반을 냅니다. collation을 바꾸기 전에 유니크 인덱스가 걸린 문자열 컬럼을 먼저 확인해야 하는 이유입니다.

## 한국어와 영문 코드 값만 다루면 general_ci 쪽이 유리함

`unicode_ci`가 더 정확하다면 그쪽을 컨벤션으로 두는 편이 낫지 않냐는 질문이 남습니다. 다루는 데이터에 따라 답이 갈립니다.

`unicode_ci`가 `general_ci`보다 정확해지는 자리는 확장, 축약, ignorable character를 처리하는 지점입니다. `ß`와 `ss`, 전각 `Ａ`와 반각 `A` 같은 경우입니다. 한국어와 영문 대문자 코드 값에는 그런 문자가 나오지 않습니다. 정확도를 얻을 자리가 없습니다.

얻는 것이 없다면 남는 것은 비용입니다. MySQL 문서는 `general_ci` 쪽 비교가 더 빠르다고 적습니다. 다만 이 환경에서 두 값의 속도를 재 보지는 않았습니다.

코드 값을 담는 컬럼에서는 동치로 보는 범위가 좁은 쪽이 의도에 가깝기도 합니다. `unicode_ci`는 전각 `Ａ`와 반각 `A`를 같은 값으로 봅니다. 식별자로 쓰는 코드에서 그 둘이 같은 값이 되기를 바라는 경우는 드뭅니다.

반대 방향도 분명합니다. 여러 언어가 섞인 이름이나 문장을 정렬해 보여줘야 한다면 `unicode_ci`가 맞습니다. 정렬 순서를 유니코드 규칙에 맞추는 것이 그 collation의 목적입니다. 어느 쪽이 옳다기보다 다루는 데이터에 맞는 쪽이 있습니다.

이 저장소가 다루는 것은 한국어 텍스트와 영문 대문자 코드였고, 그래서 당시의 컨벤션은 `general_ci`였습니다.

## 컨벤션과 다른 CREATE TABLE의 COLLATE 절

원인을 찾으려고 테이블들의 collation을 조회했습니다. 문의받은 이력 테이블만 어긋난 것이 아니었습니다. 일부 테이블에 `unicode_ci`가 적용돼 있었습니다.

당시의 컨벤션은 `utf8mb4_general_ci`였고, 특정 시점 이전에 만들어진 테이블은 그 값을 따르고 있었습니다.

원래 방식은 `CREATE TABLE`에 collation을 아예 적지 않는 것이었습니다. 적지 않으면 데이터베이스 기본값을 물려받는데, 운영 스키마에서는 그 값이 컨벤션과 같았습니다. 그래서 아무도 그 줄을 쓸 일이 없었습니다.

`order_aud`를 만든 Liquibase changelog를 열어 보니 마지막 줄이 달랐습니다.

```sql
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='주문 변경 이력';
```

`COLLATE`가 직접 적혀 있었습니다. 이렇게 적으면 데이터베이스 기본값과 무관하게 그 값이 됩니다.

## 언젠가부터 Liquibase changelog의 CREATE TABLE에 unicode_ci가 추가됨

같은 문구를 가진 changelog가 그 하나가 아니었습니다.

`COLLATE = utf8mb4_unicode_ci`가 적힌 changelog를 연도별로 세어 보니 파일 기준으로 2025년에 4개, 2026년에 26개였습니다. 드문드문 들어오다가 이듬해에 크게 늘었습니다.

새 테이블을 만들 때 기존 changelog가 참고 대상이 되기 때문입니다. 작성자가 바뀌어도 같은 문구가 그대로 붙었습니다. 이 시기에는 스키마 변경에 AI 코딩 도구도 함께 쓰고 있었는데, 도구든 사람이든 참고하는 파일은 같았습니다.

`CREATE TABLE` 문 기준으로는 서른아홉 건입니다. 한 파일에 테이블이 여럿인 경우가 있어 파일 수와 다릅니다. 조사 시점 운영 기준으로 범위는 이랬습니다.

- 테이블 기준으로 `utf8mb4_unicode_ci`인 테이블 40개
- 컬럼 기준으로 35개 테이블의 140개 컬럼
- 전체 테이블은 약 280개

구성은 두 가지였습니다. Hibernate Envers가 쓰는 `_aud` 이력 테이블이 대부분이었고, 2026년에 새로 추가된 일반 테이블 몇 개가 섞여 있었습니다.

## 컨벤션을 확인할 근거가 없었고 사람 눈으로 걸러질 값도 아니었음

컨벤션은 정해져 있었지만 저장소 어디에도 적혀 있지 않았습니다. 어느 쪽이 맞는지 알려면 먼저 만들어진 테이블의 collation을 봐야 했습니다. 그러려면 데이터베이스에 접속해 `information_schema`를 조회해야 했습니다. 그래서 AI 코딩 도구나 새로 들어온 작업자는 changelog 파일만 읽어서는 어느 쪽이 컨벤션인지 알 수 없었습니다. 먼저 들어온 changelog에 `unicode_ci`가 적혀 있었으니 거기에 맞추는 것이 그 조건에서는 자연스러운 선택이었습니다.

리뷰에서도 걸리기 힘든 게, `COLLATE = utf8mb4_unicode_ci`는 문법 오류가 아닙니다. changeset은 정상 실행되고 애플리케이션도 뜹니다. `CREATE TABLE` 마지막 줄의 값이 다른 테이블 수백 개와 같은지를 리뷰에서 매번 대조할 수는 없습니다. 그래서 서른아홉 번이 지나가는 동안 아무 데서도 걸리지 않았고, 처음 신호가 나온 것은 몇 달 뒤 데이터팀의 조인에서였습니다.

## COLLATE를 생략해도 괜찮았을까?

생략한다고 컨벤션대로 되는 것은 아니었습니다. 앞의 서른아홉 건은 `COLLATE`를 직접 적어서 어긋난 것인데, 아무것도 적지 않아도 어긋나는 경로가 따로 있습니다. 이쪽은 사람이 아니라 환경 때문입니다.

하나의 charset에는 collation이 여럿 붙는데, 그중 하나가 기본 collation으로 지정돼 있습니다. charset만 정하고 collation을 안 고르면 그 값이 적용됩니다. `utf8mb4`에는 collation이 수십 개 있고 기본은 그중 하나입니다.

데이터베이스에도 기본 collation이 따로 있습니다. `CREATE DATABASE`나 `ALTER DATABASE`로 정하는 값입니다. 그 안에서 charset도 collation도 안 적었을 때 적용됩니다. 두 값은 같을 수도 다를 수도 있습니다.

그래서 `CREATE TABLE`의 테이블 옵션은 이렇게 정해집니다. 컬럼에 따로 적지 않으면 이 값이 컬럼의 기본값이 됩니다.

1. `CHARSET`과 `COLLATE`를 둘 다 적으면 그 값
2. `CHARSET`만 적으면 그 charset의 기본 collation
3. `COLLATE`만 적으면 그 collation과 거기 딸린 charset
4. 둘 다 안 적으면 데이터베이스 기본값

2번과 4번이 다를 수 있다는 것이 함정입니다. 두 값을 조회해 보면 이렇습니다.

```sql
SELECT @@collation_database;                                    -- 스키마마다 다름
SELECT COLLATION_NAME FROM information_schema.COLLATIONS
 WHERE CHARACTER_SET_NAME = 'utf8mb4' AND IS_DEFAULT = 'Yes';   -- utf8mb4_general_ci
```

`utf8mb4`의 기본 collation은 이 환경에서는 `general_ci`입니다. MariaDB 기준이고, MySQL 8.0부터는 `utf8mb4_0900_ai_ci`라 자기 환경에서 조회해 봐야 합니다. 데이터베이스 기본 collation은 그렇지 않았습니다. 운영 스키마는 `general_ci`인데, 개발 계열 스키마 아홉 개는 전부 `unicode_ci`였습니다.

상속 때문이 아니었습니다. 서버 기본값(`@@collation_server`)은 양쪽 다 `latin1_swedish_ci`입니다. 스키마를 만들 때 적은 값이 환경마다 갈린 것입니다.

그래서 표기에 따라 결과가 이렇게 갈립니다.

| changelog 표기 | 실제 결과 | 컨벤션 |
|---|---|---|
| `DEFAULT CHARSET = utf8mb4`만 | utf8mb4_general_ci | 맞음 |
| `CHARSET`, `COLLATE` 둘 다 생략 | 스키마에 따라 갈림 | 환경에 따라 벗어남 |
| `COLLATE = utf8mb4_unicode_ci` 명시 | utf8mb4_unicode_ci | 벗어남 |

생략하면 같은 changelog가 운영에서는 컨벤션대로, 개발 환경에서는 어긋나게 실행됩니다. 환경마다 기본값이 다르면 생략은 답이 될 수 없습니다.

`CHARSET`만 적은 사람은 우연히 맞았습니다. 한 릴리스 안에서 네 케이스가 모두 관찰됐습니다.

| 테이블 | 표기 | 결과 |
|---|---|---|
| delivery_info_aud | `COLLATE = utf8mb4_general_ci` | general_ci |
| delivery_info | `CHARSET`만 | general_ci |
| reception_aud | `COLLATE = utf8mb4_unicode_ci` | unicode_ci |
| bag_types, bag_types_aud | 둘 다 없음 | unicode_ci |

테이블 기본값과 컬럼이 어긋난 경우도 있었습니다. 테이블은 `general_ci`인데 컬럼만 `unicode_ci`입니다.

```sql
SHOW CREATE TABLE temp_import;
--   `uuid` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
--   `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
```

테이블 기준으로만 조회하면 정상으로 보입니다. 현황을 볼 때 테이블 축과 컬럼 축을 모두 봐야 하는 이유입니다.

```sql
-- 테이블 축
SELECT TABLE_NAME, TABLE_COLLATION FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'
  AND TABLE_COLLATION <> 'utf8mb4_general_ci';

-- 컬럼 축
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, COLLATION_NAME FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND COLLATION_NAME IS NOT NULL
  AND COLLATION_NAME <> 'utf8mb4_general_ci';

-- 테이블 기본값과 컬럼이 어긋난 지점
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.COLLATION_NAME, t.TABLE_COLLATION
FROM information_schema.COLUMNS c
JOIN information_schema.TABLES t USING (TABLE_SCHEMA, TABLE_NAME)
WHERE c.TABLE_SCHEMA = DATABASE() AND c.COLLATION_NAME IS NOT NULL
  AND c.COLLATION_NAME <> t.TABLE_COLLATION;
```

## 그래서 조치는?

조치는 두 가지였습니다. 이미 어긋난 테이블을 고치는 것과 규칙을 적어 두는 것입니다. 범위를 재는 데는 스크립트를 썼습니다.

**이미 어긋난 테이블**은 `CONVERT TO`로 바꿉니다.

```sql
ALTER TABLE order_aud
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
    ALGORITHM = COPY, LOCK = SHARED;
```

charset은 `utf8mb4`로 두고 collation만 바꾸므로 값이 손실되지 않습니다. 다만 가벼운 작업은 아닙니다. 이 건에서는 `ALGORITHM=COPY`와 `LOCK=SHARED`로 실행했습니다. 테이블을 다시 쓰는 동안 그 테이블에 쓰기가 막히고 읽기만 됩니다.

실행 방식은 대상에 따라 나눴습니다.

| 대상 | 방식 |
|---|---|
| 운영과 스테이지에 이미 있던 테이블 | 수동 실행 |
| 아직 배포되지 않은 신규 테이블 5개 | 교정 changeset |

**이미 있던 테이블은 수동으로** 바꿨습니다. 약 490MB짜리 이력 테이블을 배포 파이프라인에 넣으면 그동안 쓰기가 막힙니다. 이 애플리케이션은 부팅 경로에서 changeset을 실행하는데, 하나가 실패하면 그 뒤가 전부 막히고 애플리케이션이 뜨지 않습니다. 오래 걸리는 작업을 그 경로에 얹을 이유가 없었습니다.

**신규 테이블은 changeset으로** 갔습니다. 아직 배포되지 않았으니 수동으로 고칠 대상이 없습니다. 그대로 두면 배포 시점에 어긋난 collation으로 새로 만들어집니다. 다섯 개 중 하나는 다른 작업자가 먼저 넣었고, 나머지 넷은 교정 changeset을 따로 만들었습니다. precondition을 걸어 이미 `general_ci`이거나 테이블이 없으면 `MARK_RAN`으로 건너뛰게 했습니다.

이미 실행된 changeset 파일을 고치는 것은 어느 쪽에서도 방법이 아닙니다. Liquibase는 실행한 changeset의 체크섬을 `DATABASECHANGELOG`의 `MD5SUM` 컬럼에 저장하고 다음 실행에서 대조합니다. 파일을 고치면 체크섬이 어긋나 중단합니다.

우회 수단이 없지는 않습니다. `validCheckSum`을 달면 그 검증은 통과합니다. 그래도 답은 같습니다. `validCheckSum`은 검증만 통과시킬 뿐 changeset을 다시 실행하지 않아서, 이미 만들어진 테이블은 그대로 남습니다. 그리고 `--liquibase formatted sql` 헤더가 없는 파일은 그 주석을 인식하지도 못합니다(부록 2). 교정은 항상 새 changeset으로 합니다.

**규칙**은 저장소의 `CLAUDE.md`와 `AGENTS.md`에 적었습니다. 사람과 AI 코딩 도구가 같은 파일을 봅니다.

- 새 테이블 changelog는 `COLLATE = utf8mb4_general_ci`를 명시한다
- 컬럼 단위로 collation을 지정하지 않고 테이블 기본값을 물려받는다
- 이미 실행된 changeset은 고치지 않고 새 changeset에서 `CONVERT TO`로 교정한다

원래 관행은 아무것도 적지 않는 것이었지만, 규칙은 직접 적는 쪽으로 정했습니다. 스키마 기본값이 환경마다 다르니 생략은 답이 될 수 없었습니다.

**전수 확인**은 스크립트로 했습니다. changelog의 `CREATE TABLE`을 파싱해 판정합니다. 판정은 셋입니다.

- `OK`: `COLLATE = utf8mb4_general_ci` 명시, 또는 `COLLATE` 없이 `CHARSET = utf8mb4`만 있음
- `WRONG`: `COLLATE`가 다른 값으로 명시됨. 어느 환경에서 실행해도 그 값이 됨
- `MISSING`: `CHARSET`과 `COLLATE`가 둘 다 없음. 실행되는 스키마의 기본값에 따라 갈림

종료 코드를 `WRONG` 건수로 두었습니다. CI 실패 판정에 그대로 쓸 수 있는 형태입니다. 다만 아직 저장소에 넣지도, 워크플로에 걸지도 않았습니다. 지금은 수동으로 돌립니다. changelog 340개에 돌린 결과는 `WRONG` 39건, `MISSING` 67건이었습니다.

두 판정을 나눈 데는 이유가 있습니다. 정적 분석 결과를 개발 데이터베이스 실측과 대조해 보니 `WRONG` 39건은 39건 모두 실측에서도 `unicode_ci`였고 오탐이 없었습니다. 반면 `MISSING` 67건 중 실측에서 `unicode_ci`인 것은 4건뿐이었습니다. 나머지 63건은 `general_ci`였습니다. 둘을 하나로 합쳤다면 오탐 63건짜리 검사가 되어 아무도 보지 않았을 것입니다.

63건이 `general_ci`인 이유는 개발 데이터베이스를 만드는 방식에 있었습니다. 개발 환경은 운영 스냅샷을 덤프해 복제합니다. 운영에서 먼저 만들어진 테이블은 덤프의 `CREATE TABLE` 문에 `general_ci`가 박힌 채로 넘어옵니다. 개발 스키마의 기본값이 `unicode_ci`여도 그 값이 적용될 자리가 없습니다.

`unicode_ci`였던 4건은 반대입니다. 아직 운영에 배포되지 않아 개발 환경에서 처음 만들어졌고, 그래서 그쪽 기본값을 물려받았습니다.

스크립트가 놓치는 것도 있습니다. 실측에서 어긋났는데 검사에 안 걸린 테이블이 5개 있었고, 전부 changelog에 없는 테이블이었습니다. 정적 분석의 대상 밖입니다.

교정을 진행한 뒤 스테이지 현황입니다.

| 구분 | 조사 시점 | 하루 뒤 |
|---|---|---|
| utf8mb4_general_ci | 235 | 275 |
| utf8mb4_unicode_ci | 44 | 4 |

남은 4개는 작업용 임시 테이블이라 고칠 필요가 없었습니다.

이건 테이블 축 기준입니다. 컬럼 축으로 보면 `temp_import`의 컬럼 11개가 그대로 남아 있습니다. 두 축을 따로 봐야 하는 이유가 정리 단계에서도 그대로 나옵니다.

조치 뒤에 잘 됐는지 보려고 문의받은 조인문을 그대로 실행했습니다. 잘 동작했습니다.

```sql
SELECT COUNT(*) AS cnt
FROM order_aud oa
JOIN code_master m
  ON m.code_group = 'channel' AND m.code_value = oa.channel;
-- 9180
```

## 마치며

collation은 문자를 저장하는 규칙이 아니라 비교하는 규칙입니다. 그래서 값을 넣고 꺼내는 동안에는 어긋나도 티가 나지 않습니다. 두 컬럼을 맞대는 순간에 처음 드러납니다. 데이터팀의 조인이 막히고 나서야 신호가 나온 것이 그래서였습니다.

컨벤션으로 두고 있던 `general_ci`의 근거도 이때 정리했습니다. 한국어 텍스트와 영문 대문자 코드에는 `unicode_ci`가 정확해지는 자리가 나오지 않습니다. 얻을 것이 없으니 더 빠른 쪽을 쓰는 선택이었고, 코드 값에서는 동치 범위가 좁은 쪽이 의도에도 가깝습니다. 다국어 텍스트를 정렬해야 하는 곳이라면 반대로 골라야 합니다.

규칙을 잘 관리하는 것은 어렵습니다. 컨벤션은 사람 머릿속과 먼저 만들어진 테이블에만 있었습니다. 새로 온 사람에게 전달되지 않았고, AI 코딩 도구도 참고할 데가 없었고, 리뷰에서 걸러질 종류의 값도 아니었습니다. 그저 잘 동작했기에 문제를 내포한 것을 몰랐습니다.

남은 것이 둘 있습니다. 하나는 검사 스크립트를 저장소에 넣고 changelog가 바뀐 PR에서 돌게 거는 일입니다. 지금은 수동으로만 돌리고 있어서, 새 PR에 어긋난 `COLLATE`가 들어와도 걸리지 않습니다.

다른 하나는 스키마 기본 collation입니다. 이 값을 컨벤션에 맞추면 `CHARSET`과 `COLLATE`를 둘 다 생략한 changelog도 어느 환경에서나 컨벤션대로 실행됩니다. 고칠 대상은 운영이 아니라 개발 계열 스키마 아홉 개입니다. 운영은 이미 컨벤션과 같습니다.

```sql
ALTER DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

서버 파라미터를 바꾸는 것은 방법이 아닙니다. `@@collation_server`는 이미 스키마 값과 무관하게 `latin1_swedish_ci`였습니다. 스키마 기본값은 만들 때 적은 값이라 서버 설정을 고쳐도 그대로 남습니다. `ALTER DATABASE`로 스키마마다 바꾸는 수밖에 없습니다. 기존 테이블에는 영향이 없고, 이 건에서는 아직 적용하지 않았습니다.

## 부록 1. 파일명은 하이픈, 본문은 언더스코어

원인이 된 changelog를 처음에는 못 찾았습니다.

```bash
grep -rn "order_aud" src/main/resources/db/liquibase/
```

`ALTER TABLE order_aud`만 나오고 `CREATE TABLE`은 안 나왔습니다. 그래서 Envers가 자동 생성한 오래된 테이블이라고 잠깐 판단했습니다. 틀렸습니다.

실제 파일명은 `260605-002-create-table-order-aud.sql`이었습니다. 파일명은 하이픈, 본문은 언더스코어를 쓰는 저장소인데, 파일 목록을 훑는 과정에서 본문 검색 결과를 놓쳤습니다. 구분자가 섞이는 저장소에서는 둘 다 잡는 형태로 검색해야 합니다.

```bash
grep -rniE "order[-_]aud" src/main/resources/db/liquibase/
```

## 부록 2. 헤더 없는 SQL은 changeset ID가 raw로 기록됨

조사 중에 `DATABASECHANGELOG`를 보다가 알게 된 것입니다. `--liquibase formatted sql` 헤더가 없는 SQL 파일도 `includeAll`로 포함되면 실행됩니다. 다만 changeset ID가 `raw`, AUTHOR가 `includeAll`로 기록됩니다.

실행은 되므로 문제가 드러나지 않습니다. 나중에 그 changeset을 추적할 때 식별자가 파일 경로에 묶여 있어 찾기가 나빠집니다.

## 참고 문헌

- [MySQL 8.4 Reference Manual, Unicode Character Sets](https://dev.mysql.com/doc/refman/8.4/en/charset-unicode-sets.html): `utf8mb4_general_ci`는 문자 간 일대일 비교만 하며 확장, 축약, ignorable character를 지원하지 않는다. `utf8mb4_unicode_ci`는 지원하며 `ß`를 `ss`와 같게 본다. `general_ci` 쪽 비교가 더 빠르고 약간 덜 정확하다.
- [MySQL 8.4 Reference Manual, Collation Coercibility in Expressions](https://dev.mysql.com/doc/refman/8.4/en/charset-collation-coercibility.html): 비교에는 coercibility 값이 가장 낮은 쪽의 collation을 쓴다. 등급은 0에서 6까지이고, 명시적 `COLLATE` 절이 0, `NULL`에서 파생된 식이 6이다.
- [MySQL 8.4 Reference Manual, Table Character Set and Collation](https://dev.mysql.com/doc/refman/8.4/en/charset-table.html): 테이블에 `CHARSET`만 적으면 그 charset의 기본 collation을 쓰고, 둘 다 적지 않으면 데이터베이스 값을 쓴다. 컬럼에 따로 적지 않으면 테이블 값이 기본값이 된다.
- [Liquibase Docs, Changeset Checksums](https://docs.liquibase.com/concepts/changelogs/changeset-checksums.html): 실행한 changeset의 체크섬을 `DATABASECHANGELOG` 테이블의 `MD5SUM` 컬럼에 저장하고, 다음 실행에서 대조한다. 실행 뒤 파일이 바뀌었으면 중단하고 오류를 낸다.
- [CUBRID 11.4 매뉴얼, 다국어 개요](https://www.cubrid.org/manual/ko/11.4/sql/i18n.html): collation의 expansion과 contraction을 한국어로 각각 "확장", "축약"으로 표기한다.
