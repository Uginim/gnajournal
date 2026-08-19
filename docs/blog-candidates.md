# 블로그 콘텐츠 후보

개인 학습 gist와 노션, 구글 드라이브 자료에서 뽑은 블로그 소재 목록. **사내 식별자, 티켓번호, 테이블명, 회사명, PR번호는 모두 제거**하고 일반화한 뒤 게시한다. (게시 콘텐츠의 과장, 거짓 금지 규칙과 사내, 타사 IP 보호 규칙 적용)

## 상태 범례
- ✅ 게시됨 (draft:false)
- 🚧 초안 있음 (draft, 게시 대기)
- ⭐ 재료가 충분해 바로 쓰기 좋음
- 🔲 미착수
- (일반화 필요) 사내 실무라 회사명과 도메인 식별자를 지우고 일반화해야 게시 가능

---

## A. 백엔드 설계, 성능

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| 🚧 ⭐ | IN 절 vs EXISTS | "먼저 조회해서 IN(list)"이 위험한 이유: 리스트 비대화(5만 개 IN), Phase 0/1 일관성, Semi-Join과 Early Termination, PreparedStatement 캐시 포기. 통합 EXISTS와 Adaptive Hybrid 대안. 초안 둘: 개념편(in-vs-exists-mysql-mariadb)과 MariaDB 로컬 재현편(in-vs-exists-mariadb-benchmark). 재현 결과: IN 서브쿼리 ≡ EXISTS(Handler 카운터 동일), 리터럴 IN 5만은 임시 테이블 추가(Rows_tmp_read 5만), JPA in_clause_parameter_padding으로 파싱 4→2회. 재현 gist [Uginim/9b85b93](https://gist.github.com/Uginim/9b85b93f8daea512d3e74e2d29ab4f3e) |
| ✅ | JPA N+1 문제 해결 | fetch join, EntityGraph, batch size |
| 🔲 | QueryDSL 동적 다중조건 검색 | BooleanBuilder와 where 파라미터 패턴 |
| 🔲 | JPA 대량 Insert 최적화 | Batch Insert가 느린 이유와 개선 |
| ⭐ | 가상계좌 입금 자동매칭 설계 | 입금과 정산 대사 자동화 (일반화 필요) |
| ⭐ | 월별 청구, 정산 자동화 파이프라인 | 매월 수작업 대량 건 제거 (일반화 필요) |
| ⭐ | 엑셀 대량 업로드 설계 | 검증, 부분실패, 롤백 전략 (일반화 필요) |
| 🔲 | 전자세금계산서 API 연동 자동화 | 발행 자동화 (일반화 필요, 타사 제품명 제거) |
| 🔲 | 알림톡 대량 발송 시스템 | 템플릿 관리와 발송 실패 재처리 (일반화 필요) |
| 🔲 | 정부 시스템 데이터 동기화 설계 | (일반화 필요) |
| ⭐ | DDD Rich Domain Model 적용기 | 서비스에 흩어진 로직을 도메인으로 |
| 🔲 | Bounded Context 의존성 정리 | 모듈 경계와 의존 방향 설계 |
| 🔲 | 설계 검증 체크리스트 만들기 | 공용 리소스 그룹 셀프 리뷰 (일반화 필요) |
| 🔲 | 요금제(가격정책) 시스템 유연 설계 | (일반화 필요) |
| 🔲 | 계약 만료 시 연관 데이터 자동 정리 | 비활성화 로직 설계 (일반화 필요) |

### JPA, Hibernate 심화 (기존 후보)

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| 🚧 | orphanRemoval + 유니크키 충돌 | clear+add 치환 시 INSERT가 DELETE보다 먼저 나가 UK 위반. ActionQueue flush 순서. 게시 대기 draft |
| 🔲 | 엔티티 리스너에서 DI가 안 되는 이유 | `@EntityListeners` 콜백은 Hibernate가 생성해 스프링 빈 주입 불가, 우회법 |
| 🔲 | pooled-lo ID 채번 전략 | 시퀀스 선점 이유, allocationSize 트레이드오프 |
| 🔲 | Hibernate Envers | 감사 로그 내부동작, 운영 한계 |

## B. 데이터베이스 (Oracle, PostgreSQL, MySQL)

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| ✅ | 데이터베이스 정규화 시리즈 | 1NF~BCNF, 이상현상, 함수적 종속 (1~6편 게시, 7편 draft) |
| 🚧 | ORA-08103: object no longer exists | 이름은 그대로여도 세그먼트 실체가 바뀌면 나는 오류. DATA_OBJECT_ID, 동시 DDL, 인덱스 재빌드. 초안 완료 |
| ⭐ | 정류장, 회차 매핑 로직 설계기 | 교통카드 거래내역과 버스운행 데이터 매핑 (일반화 필요) |
| ⭐ | Oracle/Tibero Global Temporary Table로 집계 성능 살리기 | 임시 테이블 삭제(DELETE) 연산으로 대량 집계가 수 시간 지연되던 것을 GTT(세션/트랜잭션 스코프, Redo log 미발생)로 제거. WITH절 대안의 한계(JDBC 버전별 오류)도. 교통 데이터 집계 실무 일반화. 원본 경로는 로컬 비공개 색인 `docs/private/blog-source-index.md` 참조 (일반화 필요) |
| ⭐ 🔲 | 국산 DBMS Tibero에서 Oracle 호환 다루기 | Oracle 호환 계층, SDO 공간함수 호환 지점과 우회, 마이그레이션 시 갈리는 문법. 자료가 드문 틈새 주제. 원본 경로는 비공개 색인 참조 (일반화 필요: 발주처명과 회신 문서 문구 제거) |
| ✅ | Linear Referencing으로 버스 정류장 구간 만들기 | 노선에 Measure 부여 후 두 Measure 사이 추출, 오투영 판별(직전/현재/직후 순서). 2026-07-27 게시. QGIS 화면은 지명 블러 처리 |
| 🔲 | 대용량 집계 프로시저 설계 | PL/SQL 가공 패턴 (일반화 필요, 위 GTT 항목과 통합 가능) |
| 🔲 | PostgreSQL + PostGIS 공간쿼리 시작하기 | |
| 🚧 | MySQL 공간 데이터를 JPA로 다루기 | POINT, SRID 4326, 축 순서, ST_Distance_Sphere. 초안 완료 |
| 🔲 | SQL 쿼리 튜닝 실전 | 실행계획 읽고 인덱스 잡기 |
| 🔲 | 인덱스 설계 기본기 | 복합 인덱스 컬럼 순서, 커버링 인덱스 |
| 🔲 | 트랜잭션과 락 | InnoDB 락 종류, MVCC, Spring @Transactional propagation. 격리수준과 Non-repeatable Read 포함. 시리즈감(3편 분할 가능) |
| 🔲 | VARCHAR 정의 길이와 성능 (255 경계의 실체) | "255 경계"는 바이트 기준(utf8mb4는 63자에서 넘음), 디스크 크기는 정의 길이 무관, 실제 차이는 MEMORY 임시 테이블 고정 행. 실측 포함. gist [RECO-Hyeonuk/8fda6a2](https://gist.github.com/RECO-Hyeonuk/8fda6a230d2cba50d1e32373f8e7da2e). 일반 지식이라 사내 식별자 없음 |
| 🔲 | MyBatis 쓸 때 고려할 점 | |
| 🔲 | 수십억 건을 Redis + HBase로 저장하는 사례 (아티클 리뷰) | 원문 출처 명시 필요 |

## C. 인프라, 운영, 배포

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| ⭐ | WAS 이중화 + Apache 무중단 배포 | 이중화 구성과 무중단 배포 절차. 사내 가이드 문서가 있어 바로 정리 가능. 원본 경로는 비공개 색인 참조 (일반화 필요) |
| 🔲 | Spring Batch 도입기 | 오래 걸리는 작업을 백그라운드로 |
| ⭐ | 크론 청구서 자동생성 배포 회고 | 운영 이슈와 대응 |
| 🔲 | Docker 기초 개념 정리 | 이미지 vs 컨테이너, ENTRYPOINT와 CMD |
| 🔲 | 쿠버네티스, 도커 컨테이너 인프라 입문 | |
| 🚧 | VMware "Internal error" 부팅 오류 해결 | 잔여 락 파일(.lck), 프로세스 재시작, 권한, 백신, Hyper-V 충돌. 초안 완료 |
| 🔲 | 리눅스 sed 명령어 실전 활용 | |
| 🔲 | Git 명령어 취소 모음 | add, commit, push 되돌리기 |
| 🔲 | Git Bash 한글 깨짐 등 환경설정 팁 | |
| 🔲 | 배포 직후 마이그레이션 체크리스트 | |
| 🔲 | self-hosted 러너 좀비 자동 복구 (러너 워치독) | 51시간 CI 장애, 원인(actions/runner#3892), 감지와 복구 자동화, 실전 효과. gist Uginim (본인 프로젝트, IP 안전) |

## D. 언어, 프레임워크 학습

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| 🔲 | Effective Java 핵심 아이템 정리 (시리즈) | |
| 🔲 | Spring 핵심 개념 다시 정리 | DI, IoC, AOP |
| 🔲 | 서블릿으로 이해하는 웹 동작 원리 | |
| 🔲 | Kotlin으로 Spring 하기 | Null Safety, data class 등 Java와 달라지는 점. 널 안정성(플랫폼 타입, `?.`, `?:`, `!!`, 자바 상호운용 함정)은 별도 편으로도 가능 |
| 🔲 | JavaScript ES6 핵심 문법 정리 | |
| 🔲 | Maven vs Gradle 빌드 도구 이해하기 | |
| 🚧 | Jetpack Compose 초기 세팅 빌드 에러 4가지 | Empty Activity 템플릿, AAR metadata SDK 요구, mutableStateOf import, Gradle Wrapper. 초안 완료 |
| 🔲 | 안드로이드 개인 개발자 앱 출시 진입장벽 넘기 | |
| 🔲 | WebGL로 웹에서 3D 그리기 입문 | |

## E. 프론트, 시각화, 지도(GIS)

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| 🔲 | 카토그램(Cartogram)으로 통계, 선거 지도 만들기 | |
| 🔲 | AG-Grid로 대용량 표 다루기 | 실전 팁 |
| 🔲 | OpenLayers로 실시간 위치 지도에 찍기 | 선박, 차량 (일반화 필요) |
| 🔲 | 측지 좌표계를 WGS84로 통합하기 | 좌표 변환 실무 |

## F. 알고리즘, CS

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| ⭐ | 문자열 유사도 알고리즘 비교 | Hamming, Smith-Waterman, Sørensen-Dice |
| 🔲 | Union-Find(서로소 집합) 정리 | |

## G. Claude Code, 블로그 운영 (그나저나 메모 자체 주제)

| 상태 | 주제 | 핵심 내용 |
|---|---|---|
| ✅ | 프롬프트 캐싱 구조 | prefix 일치, 무효화 조건, 비용 구조, 실측 |
| 🚧 | 토큰 절감 도구 | 공식 기능과 서드파티 도구, 캐시 위험 등급. 임시 비공개 |
| 🔲 | 컨텍스트가 많으면 정확도가 떨어지나 | Lost in the Middle(Liu et al., 2023) 근거. 실측 방향 |
| 🔲 | 검색 스니펫은 무엇으로 만들어지나 | meta description vs 본문 발췌 |
| 🔲 | 제목 날짜 신선도 신호 | 연도 vs 풀 날짜 vs 본문 날짜 |
| 🔲 | 네이버 Yeti 크롤러 | 정의, User-Agent, 점검법 |
| 🔲 | DNS 기초 | apex, www, A, AAAA, CNAME (입문자용) |
| ⭐ | 라벨 트리거 Claude PR 리뷰 자동화 | GitHub Actions 재사용 워크플로우, 라벨을 1회 실행 버튼으로 쓰는 패턴, OAuth 토큰 vs API 키, 권한 하향 원칙. 무료 AI 리뷰 종료 후 중앙 리뷰 체계로 전환한 기록. gist [Uginim/0570d01](https://gist.github.com/Uginim/0570d01d29af102b6b0981c4435189ab). 본인 8개 저장소라 IP 안전, 타사 제품명은 "무료 AI 리뷰"로 일반화. 블로그 초안 포함 |

## 부록: 추가 후보 (여유 있을 때)

- 임베디드, 선박 IoT: NMEA0183/2000 신호 파서(C++), AIS 실시간 선박 위치 추적, 레거시 DLL을 확장으로 쓰기, 기상데이터 수집 Agent, Canvas 바람, 조류 흐름 애니메이션 (일반화 필요)
- 성장, 회고: 반기 회고(질적 성장 vs 가시적 성과), 코드리뷰로 배운 온보딩, 나만의 공부법, 컨퍼런스 정리, 위클리 콘테스트 풀이 회고
- 도구, 생산성: 노션으로 개발 지식 관리, 개발자 Mac 단축키와 세팅, 책 리뷰로 수익화
- 사이드 프로젝트: 혼자 만들고 싶은 앱 아이디어(단어암기 Meeemo, 위치기반 ToDo, 탭관리 크롬확장, 독서목표 관리앱)
- 재테크, 독서: 배당투자 독후감
- 여행, 라이프: 호텔 비교, 여행 코스와 맛집

---

## 우선순위 추천 (다음에 쓰기 좋은 순서)

1. **IN 절 vs EXISTS** (A): 상세 노트가 있어 거의 완성형, 실무 인기 주제, 게시본 다듬기만
2. **트랜잭션과 락** (B): 시리즈로 확장 가능, 검색 수요 큼
3. **가상계좌 자동매칭 / 청구, 정산 자동화** (A): 성과 수치가 명확한 대표작 (일반화 필요)
4. **DDD Rich Domain Model 적용기** (A): 최근 관심사와 연결
5. **JPA N+1, Batch Insert** (A): 검색 유입 많은 스테디셀러
6. **정류장 매핑 설계기** (B): 차별화되는 도메인 경험 (일반화 필요)

초안 완료된 4편(Compose, ORA-08103, VMware, MySQL 공간)은 히어로 제작과 존댓말 최종 검수 후 게시 대기.

## 제외 (사내 내용, 그대로는 게시 부적합)

티켓번호(UP20-*), contract, working-spot, shared-container 도메인, PR 리뷰, 서비스 리네이밍, SB3 마이그레이션, PRD 등. 정제해도 특정 조직이 드러나면 게시하지 않는다. A, B 섹션의 "일반화 필요" 항목은 회사명과 도메인 식별자를 지우고 일반 사례로 재구성했을 때만 게시한다.
