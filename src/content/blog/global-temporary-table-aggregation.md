---
title: '집계용 중간 결과 테이블을 Global Temporary Table로 바꾸기'
description: '집계 중간 결과를 일반 테이블 하나에 담고 매 실행 앞에서 DELETE로 비우면 비용이 세 군데서 나옵니다. Global Temporary Table이 그중 무엇을 없애고, redo 감소는 왜 조건부인지 Oracle 12c 문서를 근거로 정리합니다.'
pubDate: 'Jul 27 2026'
tags: ['Oracle', '데이터베이스', '성능', 'SQL']
category: 'database'
draft: false
---
예전에 매일 정해진 시간에 Oracle 프로시저로 실행되는 일 배치를 다룬 적이 있습니다. 여러 원천 데이터를 가공해 중간 테이블에 넣고, 뒤에 이어지는 단계들이 그 결과를 반복해서 읽는 방식이었습니다.

이 배치가 만드는 원천 데이터는 오전 9시쯤 전달되는 보고 자료에 들어가야 했습니다. 그런데 배치가 점점 느려지면서 원천 데이터가 그 시간까지 나오지 못하는 일이 생겼고, 이를 해결해야 했습니다.

당시 제가 주목한 부분은 임시로 쓰는 테이블을 채우고 비우는 과정이었습니다. 특히 배치를 실행할 때마다 지난 데이터를 모두 지우는 `DELETE`의 비용을 줄일 수 있을지 고민했습니다. 이 글에서는 그 과정에서 Global Temporary Table을 도입했던 경험을 다룹니다.

> 과거 업무 사례에서는 특정 조직이나 시스템을 알아볼 수 있는 이름과 데이터 형태를 빼고 구조만 일반화했습니다. 본문의 SQL과 측정값은 회사 코드나 데이터를 옮긴 것이 아니라, 별도의 실험 환경에 단순한 테이블을 만들어 얻은 결과입니다. 당시 사용한 Oracle Database 계열과 현재 실험 환경의 버전도 다르므로 결과는 환경에 따라 달라질 수 있습니다.

## DELETE에 드는 비용을 줄일 수 있을까?

당시 Oracle을 막 공부하던 중이라, 행을 지우는 단순한 명령으로 보이는 `DELETE`에 실제로 어떤 비용이 드는지부터 생각해 봤습니다. undo와 redo, 인덱스 정리까지 함께 일어나는 작업이었기 때문입니다.

먼저 이 `DELETE`가 왜 필요한지 코드를 따라가 봤습니다. 프로시저는 일반 테이블 하나를 중간 작업 공간으로 쓰고 있었습니다. 배치가 시작되면 지난 실행이 남긴 행을 모두 지우고 여러 원천 테이블을 가공한 결과를 다시 채웠습니다. 뒤에 이어지는 집계 단계들은 이 테이블을 반복해서 읽었습니다. 한 번 실행할 때는 꼭 필요하지만 배치가 끝난 뒤까지 남겨 둘 이유는 없는 데이터였습니다.

일반 테이블은 배치가 끝나도 행을 그대로 보존합니다. 다음 실행에서는 이전 데이터부터 지워야 했고, 데이터가 늘수록 비우는 양도 함께 늘었습니다.

`DELETE`로 비우면 비용이 세 군데서 나옵니다.

첫째, 지우는 행마다 undo가 생기고 그 undo는 redo에 기록됩니다. 넣을 때 한 번, 지울 때 또 한 번 로그를 남기는 셈입니다.

둘째, 인덱스도 함께 정리됩니다. 지우는 행마다 인덱스 쪽 작업이 따라붙습니다.

셋째, `DELETE`는 테이블이 쓰던 공간의 최고 사용 지점(High Water Mark)을 낮추지 않습니다. 그래서 비운 뒤에도 전체 스캔은 빈 블록까지 읽습니다.

처음에는 `DELETE`를 `TRUNCATE`로 바꾸는 방법을 생각했습니다. `TRUNCATE`는 행을 하나씩 지우지 않고 High Water Mark도 되돌립니다. 한 세션에서 순서대로 처리하는 구조라면 적용하기 쉬운 방법입니다.

다만 `TRUNCATE`로 바꿔도 매 실행 앞에서 테이블을 비우는 코드는 그대로 남습니다. 여러 트랜잭션에 걸쳐 중간 결과를 사용하되 마지막 집계가 끝난 뒤에는 보존할 필요가 없는 구조라면, 일반 테이블을 계속 비워 쓰기보다 데이터의 수명을 세션에 맞추는 편이 자연스럽습니다. 이런 상황에선 Global Temporary Table이 알맞았습니다.

## Global Temporary Table로 바꾸니 DELETE가 사라졌음

제가 한 조치는 집계 로직을 다시 짜는 것이 아니었습니다. 기존 일반 테이블이 맡던 중간 결과 저장 역할을 Global Temporary Table로 옮기고, 프로시저의 `INSERT`와 후속 조회가 새 테이블을 보도록 바꿨습니다. 최종 집계 결과를 저장하는 일반 테이블은 그대로 두었습니다. 마지막으로 프로시저 시작 부분에 있던 대량 `DELETE`를 제거했습니다.

Global Temporary Table은 정의와 데이터의 수명을 분리한 테이블입니다. 정의는 일반 테이블처럼 영구히 남아 모든 세션이 같은 정의를 보지만, 데이터는 세션마다 격리되어 트랜잭션이나 세션이 끝나면 사라집니다. 데이터는 세션의 임시 테이블스페이스에 저장됩니다.

```sql
CREATE GLOBAL TEMPORARY TABLE agg_scratch (
  bucket   NUMBER,
  metric   NUMBER,
  value    NUMBER
) ON COMMIT PRESERVE ROWS;
```

비우는 단계를 없애면 앞에서 살펴본 비용 세 가지도 함께 사라집니다. 지울 행이 없으니 그만큼의 undo와 인덱스 정리가 생기지 않고, 매 실행은 빈 테이블에서 시작합니다.

비우는 시점은 정의할 때 고릅니다. `ON COMMIT DELETE ROWS`는 트랜잭션이 끝날 때 데이터를 비우고, `ON COMMIT PRESERVE ROWS`는 세션이 끝날 때까지 데이터를 유지합니다. 당시 프로시저는 중간에 `COMMIT`한 뒤에도 같은 중간 결과를 계속 읽어야 했습니다. 그래서 새 테이블은 `PRESERVE ROWS`로 만들었습니다.

![일반 테이블에서는 매 실행이 DELETE로 비우고, Global Temporary Table에서는 그 단계가 사라지는 비교](../../assets/gtt-delete-vs-auto.svg)

세션 격리는 이 사례에서 직접 얻으려던 이점은 아니었습니다. 여러 실행을 동시에 돌리는 환경에서는 실행별 키 컬럼 대신 세션 격리를 활용할 수도 있습니다. 여기서 필요했던 것은 배치 세션이 끝날 때 중간 결과도 함께 사라지는 수명이었습니다.

이렇게 바꾸고 나니 집계 로직은 그대로인데 중간 결과의 수명만 달라졌습니다. 배치 세션이 끝나면 행이 사라지므로 다음 실행을 위해 미리 비울 필요가 없었고, 프로시저의 첫 단계였던 대량 `DELETE`도 함께 사라졌습니다.

## Global Temporary Table은 정말 redo를 만들지 않을까?

"Global Temporary Table은 redo를 만들지 않는다"는 설명을 자주 봅니다. 하지만 조건을 빼면 정확한 설명이 아닙니다.

Oracle 문서에 따르면 기본 설정에서는 Global Temporary Table의 undo 레코드가 undo 테이블스페이스에 저장되고 redo에도 기록됩니다. 일반 테이블의 undo를 관리하는 방식과 같습니다. Global Temporary Table에 데이터를 넣고 지울 때도 변경을 되돌릴 undo가 생기며, 이 undo가 redo를 만듭니다.

redo를 없애려면 temporary undo 기능을 켜야 합니다. 초기화 파라미터 `TEMP_UNDO_ENABLED`를 `TRUE`로 두면, Global Temporary Table의 undo가 undo 테이블스페이스 대신 임시 테이블스페이스에 저장되어 redo에 기록되지 않습니다. 이 기능은 Oracle 12c에서 추가됐습니다.

![TEMP_UNDO_ENABLED가 꺼지면 undo가 undo 테이블스페이스로 가서 redo에 기록되고, 켜면 임시 테이블스페이스로 가서 redo에 기록되지 않는 경로 비교](../../assets/gtt-temp-undo-redo.svg)

Global Temporary Table로 바꾸는 것만으로 redo가 모두 사라지는 것은 아닙니다. redo를 더 줄이려면 temporary undo도 함께 켜야 합니다.

과거 사례에서 Global Temporary Table을 도입한 이유는 redo보다 비우는 단계를 없애는 데 있었습니다. 당시 환경의 설정값이나 redo 측정 자료는 이 글에 사용하지 않았습니다. redo와 temporary undo의 관계는 Oracle 문서로 확인하고, 다음 절의 별도 실험 환경에서 다시 측정했습니다.

## 직접 다시 측정해 봄

측정은 컨테이너로 띄운 Oracle AI Database 26ai Free(23.26.2.0.0)에서 진행했습니다. 컬럼 세 개와 인덱스 하나로 구성한 실험용 테이블에 20만 행을 넣었습니다. 아래 숫자는 과거 업무 환경의 실측값이 아니라 별도 실험에서 얻은 값입니다.

redo는 `v$mystat`의 `redo size`를 작업 전후로 빼서 얻었습니다. 같은 스크립트를 두 번 돌렸고 괄호 안이 2회차입니다.

### 인덱스를 없애니 DELETE의 redo가 크게 줄었음

| 작업 | 인덱스 있음 | 인덱스 없음 |
|---|---|---|
| 일반 테이블에 20만 행 INSERT | 33,511,148 (33,473,884) | 5,175,660 (5,109,396) |
| 그 20만 행을 DELETE | 50,398,400 (50,399,256) | 5,289,584 (5,310,616) |

비우는 동작이 채우는 동작보다 로그를 더 남겼습니다. 대량 `DELETE`가 집계 배치의 병목 후보가 될 수 있음을 확인한 결과입니다.

인덱스를 지우고 같은 측정을 하면 `DELETE`의 redo가 10분의 1로 떨어집니다. 지운 행마다 따라붙는 인덱스 정리가 이 조건에서는 `DELETE` redo의 대부분이었습니다. 다만 이 비율은 인덱스 개수와 컬럼 값 분포에 따라 달라집니다. 위 인덱스는 값이 1000종류인 컬럼 하나에 걸린 비고유 인덱스입니다.

### DELETE 후에는 빈 테이블도 이전 블록을 읽었음

| 시점 | blocks | 빈 테이블 전체 스캔 consistent gets |
|---|---|---|
| INSERT 직후 | 536 | |
| DELETE 직후 | 536 | 539 |
| TRUNCATE 직후 | 0 | 1 |

20만 행을 모두 지운 뒤에도 블록 수는 536 그대로였습니다. 행이 하나도 없는 테이블을 전체 스캔하는 데도 블록 539개를 읽었습니다. `TRUNCATE` 뒤에는 같은 스캔이 1로 떨어졌습니다. 최고 사용 지점을 낮추느냐 그대로 두느냐에 따라 읽는 블록 수가 달라졌습니다.

### temporary undo를 켜니 GTT의 redo가 거의 사라졌음

| 대상 | INSERT redo | DELETE redo |
|---|---|---|
| 일반 테이블 | 33,511,148 | 50,398,400 |
| GTT, `TEMP_UNDO_ENABLED = FALSE` | 17,115,828 | 36,900,848 |
| GTT, `TEMP_UNDO_ENABLED = TRUE` | 266,804 | 2,536 |

Global Temporary Table로 바꾸기만 해도 INSERT의 redo는 절반쯤 줄었습니다. 그래도 절반은 남았습니다. 이 결과만 봐도 "Global Temporary Table은 redo를 만들지 않는다"는 설명은 정확하지 않습니다.

`TEMP_UNDO_ENABLED`를 켜자 남아 있던 절반이 사라졌습니다. INSERT는 앞 줄의 1.6퍼센트로, DELETE는 거의 0으로 떨어졌습니다. 그 절반은 undo에서 나왔고, undo가 임시 테이블스페이스로 옮겨 가자 redo에 기록되지 않았습니다.

`TEMP_UNDO_ENABLED`는 세션이 임시 객체를 쓰기 시작하면 바꿀 수 없습니다. 그래서 `FALSE`와 `TRUE`를 각각 새 세션에서 쟀습니다.

## 지금 다시 본다면 WITH 절은 어땠을까?

WITH 절은 당시 검토했던 선택지가 아닙니다. 그때 제가 실제로 한 조치는 일반 중간 테이블을 Global Temporary Table로 바꾸고 시작 단계의 `DELETE`를 없앤 것까지였습니다. 시간이 지나 이 글을 정리하면서, 중간 결과 테이블 자체를 없앨 방법도 있었을지 다시 생각해 봤습니다.

중간 결과를 별도 테이블 없이 쿼리 안의 WITH 절(공통 테이블 식, Common Table Expression)로 둘 수도 있습니다. 한 쿼리 안에서 중간 결과를 한 번 정의해 쓰고 끝난다면 중간 결과 테이블을 따로 만들 필요가 없어 WITH 절이 더 간결합니다.

다만 단계가 많거나 같은 중간 결과를 여러 단계에서 반복 참조하면 판단이 달라집니다. WITH 절의 결과를 옵티마이저가 한 번 계산해 재사용할지, 참조할 때마다 다시 계산할지는 쿼리와 버전에 따라 달라집니다. 지금 다시 보더라도 중간 결과를 여러 쿼리에 걸쳐 재사용하고 그 내용을 직접 통제해야 했던 당시 구조에는 Global Temporary Table이 더 예측 가능한 선택이었습니다.

## Global Temporary Table이 항상 맞는 것은 아님

Global Temporary Table은 세션마다 자기만의 중간 결과가 필요하고 매 실행 비워야 하는 자리에 잘 맞습니다. 물론 쓰지 말아야 할 자리도 있습니다.

여러 세션이 함께 읽어야 하는 결과라면 Global Temporary Table을 쓸 자리가 아닙니다. 세션 격리가 오히려 방해가 되므로 일반 테이블에 두어야 합니다. 시스템이 중단돼도 남아야 하는 데이터도 마찬가지입니다. Global Temporary Table의 데이터는 정의상 복구 대상이 아니라, 시스템 장애 시 백업과 복구가 제공되지 않습니다.

옵티마이저 통계도 살펴봐야 합니다. 데이터가 세션마다 달라 실제 데이터 양과 맞지 않는 통계로 실행계획이 잡히면 집계가 느려지기도 합니다. 이때는 세션 단위 통계나 힌트로 계획을 맞춰야 하는 경우도 있습니다.

## 마치며

핵심은 특정 문법이나 기능보다 중간 결과를 어디에 둘지 정하는 일이었습니다. 한 번 실행할 때만 필요한 데이터를 일반 테이블에 두면 다음 실행마다 대량 `DELETE`가 필요합니다. Global Temporary Table에 두면 세션이 끝날 때 데이터도 사라지므로 비우는 단계를 없앨 수 있습니다.

redo는 별개의 문제였습니다. 26ai Free에서 다시 측정해 보니 Global Temporary Table로 바꾸는 것만으로 INSERT의 redo가 절반쯤 줄었고, 나머지 절반은 `TEMP_UNDO_ENABLED`를 켰을 때 사라졌습니다. "redo를 만들지 않는다"도, "redo와 무관하다"도 아닙니다.

이 글의 측정값은 26ai Free에 같은 구조를 만들어 20만 행으로 시험한 결과입니다. 실제 적용할 때는 같은 데이터와 실행계획으로 전후를 다시 재 보는 편이 좋습니다.

## 부록: 측정에 쓴 스크립트

컨테이너는 `docker run -d --name gtt-lab -p 15210:1521 -e ORACLE_PASSWORD=oracle gvenzl/oracle-free:23-slim`로 띄웠습니다. `redo size`를 읽는 함수는 PL/SQL 안에서 롤 권한이 적용되지 않으므로, `SYS`로 `v_$mystat`과 `v_$statname`에 직접 `SELECT` 권한을 준 뒤 만들어야 합니다.

```sql
CREATE TABLE agg_plain (bucket NUMBER, metric NUMBER, val NUMBER);
CREATE INDEX agg_plain_ix ON agg_plain (bucket);

CREATE GLOBAL TEMPORARY TABLE agg_gtt (bucket NUMBER, metric NUMBER, val NUMBER)
  ON COMMIT PRESERVE ROWS;
CREATE INDEX agg_gtt_ix ON agg_gtt (bucket);

CREATE OR REPLACE FUNCTION my_redo RETURN NUMBER IS
  v NUMBER;
BEGIN
  SELECT s.value INTO v
    FROM v$mystat s JOIN v$statname n ON n.statistic# = s.statistic#
   WHERE n.name = 'redo size';
  RETURN v;
END;
/
```

측정은 작업 전후의 `redo size`를 빼는 방식입니다. 대상 테이블만 바꿔 같은 방법으로 위 표의 값을 얻었습니다.

```sql
DECLARE r0 NUMBER;
BEGIN
  r0 := my_redo;
  INSERT INTO agg_plain
  SELECT MOD(LEVEL, 1000), LEVEL, LEVEL * 1.5 FROM dual CONNECT BY LEVEL <= 200000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('INSERT redo = ' || (my_redo - r0));
END;
/
```

최고 사용 지점은 `DBMS_STATS.GATHER_TABLE_STATS` 뒤에 `user_tables.blocks`로 보고, 빈 테이블을 전체 스캔할 때 읽는 블록 수는 `consistent gets` 통계를 같은 방식으로 빼서 봤습니다.

## 참고 문헌

- [Oracle Database Concepts 12c R2, Overview of Tables](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/cncpt/tables-and-table-clusters.html): 임시 테이블의 정의는 영구히 남고 데이터는 트랜잭션이나 세션 동안만 존재한다.
- [Oracle Database Administrator's Guide 12c R2, Managing Tables](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/admin/managing-tables.html): 임시 테이블 데이터는 정의상 임시라 시스템 장애 시 백업과 복구가 제공되지 않는다.
- [Oracle Database Administrator's Guide 12c R2, Managing Undo](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/admin/managing-undo.html): 기본 설정에서 임시 테이블의 undo는 undo 테이블스페이스에 저장되고 redo에 기록된다. `TEMP_UNDO_ENABLED`를 켜면 임시 테이블스페이스에 저장되어 redo에 기록되지 않는다.
- [Oracle Database SQL Language Reference 12c R2, TRUNCATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/sqlrf/TRUNCATE-TABLE.html): `TRUNCATE TABLE`은 롤백할 수 없다.
