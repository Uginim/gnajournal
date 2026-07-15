# 본문 도식(인라인 SVG) 작업 이력, 제작 방법

정규화 시리즈 등 **본문에 들어가는 설명용 도식**을 어떻게 만들었는지에 대한 기록. 히어로/OG 이미지(수채화 마스코트 PNG)는 별도 문서 [`hero-image-prompt.md`](./hero-image-prompt.md) 참고.

## 도식 종류 두 가지

| 종류 | 제작 방식 | 파일 | 문서 |
|---|---|---|---|
| **본문 인라인 도식** | **손으로 작성한 SVG** (아이콘, 표, 화살표) | `src/assets/db-*.svg`, `spring-*.svg` | **이 문서** |
| 히어로/OG 이미지 | 이미지 생성 모델(Gemini) + 참고 이미지 | `src/assets/*-N-*.png` 등 | `hero-image-prompt.md` |
| 일부 삽화(키 계층 등) | 이미지 생성 모델 (표를 그림으로 대체) | `db-key-hierarchy.png` | `hero-image-prompt.md` |

이 문서는 **첫 번째(손으로 짠 SVG)** 를 다룬다. 정규화 1~7편 본문 도식은 전부 이 방식이다.

---

## 왜 SVG를 손으로 짰나

- **텍스트가 살아있다**: 한글 라벨이 실제 텍스트라 선명하고, 확대해도 안 깨지고, 검색, 접근성(스크린리더)에 잡힌다. (이미지 생성 모델은 글자를 그림으로 그려서 깨지거나 오타가 남, 정규화 히어로에서 겪은 `(N)` 문제와 같은 이유.)
- **정확하다**: `(NULL)`, `직원ID (PK)`, 화살표 방향 같은 정보를 오차 없이 배치할 수 있다. 개념 도식은 정확성이 생명이라 생성모델보다 수작업 SVG가 맞다.
- **가볍고 수정 쉽다**: 각 파일 1.5~4KB. 라벨 오타나 색을 고칠 때 텍스트만 바꾸면 된다.
- **일관성**: 아래 디자인 토큰을 공유해 시리즈 전체가 같은 톤을 유지한다.

---

## 제작 절차 (새 도식 추가 시)

1. **무엇을 보여줄지 한 문장으로 정한다.** 도식 하나 = 개념 하나. (예: "직원이 없는 부서는 키가 비어 삽입 못 함")
2. **`src/assets/db-<주제>-<개념>.svg`** 파일을 만든다. 아래 스켈레톤 + 디자인 토큰으로 작성.
3. 레이아웃은 **가로형(horizontal)** 기준. `viewBox="0 0 <w> <h>"` 로 좌표계를 잡고 `<rect>`(셀), `<text>`(라벨), `<path>`(화살표)로 조립.
4. **제목**(좌상단)과 **캡션**(하단)을 넣는다. 문제 상황은 빨강 계열, 정상은 초록/남색 계열로 대비.
5. 본문 마크다운에 임베드:
   ```md
   ![<정보를 다 담은 서술형 alt 텍스트>](../../assets/db-<주제>-<개념>.svg)
   ```
   Astro가 SVG를 그대로 서빙한다. **alt는 도식 내용을 문장으로 풀어 쓴다**(접근성 + SEO, 아래 예시 참고).
6. 로컬 `npm run dev` 로 확인 → 빌드, 배포.

### SVG 스켈레톤
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 580 184"
     font-family="-apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif">
  <!-- 제목 (좌상단) -->
  <text x="40" y="24" font-size="13" font-weight="700" fill="#1f2330">제목</text>

  <!-- 표 헤더 / 셀: rect + 가운데 정렬 text -->
  <rect x="40" y="36" width="110" height="36" fill="#eef0ff" stroke="#4f46e5" stroke-width="1.4"/>
  <text x="95" y="59" text-anchor="middle" font-size="12.5" font-weight="700" fill="#4f46e5">직원ID (PK)</text>

  <!-- 캡션 (하단) -->
  <text x="40" y="172" font-size="12.5" font-weight="600" fill="#5b5fb0">한 줄 요약 캡션</text>
</svg>
```

---

## 디자인 토큰 (실제 사용 색, 시리즈 공통)

시리즈 전체가 아래 팔레트를 공유한다. 새 도식도 이 안에서 고른다.

| 용도 | 색 | 비고 |
|---|---|---|
| 본문 텍스트 | `#1f2330` | 기본 글자 |
| 보조/캡션 텍스트 | `#5b5fb0`(남색 계열), `#80828f`(회색) | |
| 중립 테두리 | `#cfd0db`, `#8a8a96` | 일반 셀 경계 |
| 중립 배경 | `#f7f7fb`, `#f4f4f6`, `#ffffff` | 강조 없는 셀 |
| **강조(키/남색)** | 선 `#4f46e5`, 배경 `#eef0ff`/`#e7ecff`, 글자 `#4f46e5`/`#5b5fb0` | PK, 결정자 등 |
| **문제/오류(주황, 빨강)** | 선, 글자 `#d9480f`, 배경 `#fff4ec`/`#ffeede` | 이상현상, 위반. `✕` 마커 |
| **정상/성공(초록)** | 선, 글자 `#2f9e44`, 배경 `#eef9f0`/`#e9f7ef` | 허용, 정상. `✓` 마커 |

- **폰트**: `-apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif` (macOS, Windows 한글 폴백 포함)
- **글자 크기**: 제목 13 / 헤더, 라벨 12.5~13(weight 700) / 캡션 12.5(weight 600)
- **마커**: 문제 `✕`(빨강), 정상 `✓`(초록)

---

## alt 텍스트 규칙

도식의 정보를 **문장으로 완전히 풀어 쓴다.** 스크린리더 사용자와 검색엔진이 그림 내용을 텍스트로 받는다.

예 (2편 삽입 이상):
```
![인사부를 등록하려면 직원ID와 직원명이 NULL이 되어 키가 비어 버리므로
  부서만 따로 삽입할 수 없음을 보여주는 삽입 이상 도식](../../assets/db-anomaly-insertion.svg)
```
"~도식" 으로 끝맺어 이미지 성격을 명시한다.

---

## 기존 도식 목록 (정규화 시리즈)

최초 작성: `09cdfea 데이터베이스 정규화 시리즈(1~6편)` 커밋. (7편 자연키/대리키 도식은 draft.)

| 편 | 파일 | 보여주는 것 |
|---|---|---|
| 1편 무결성, 키 | `db-integrity-entity.svg` | 회원ID 중복, NULL → 개체 무결성 위반 |
| | `db-integrity-referential.svg` | 존재하지 않는 member_id 참조 차단 |
| | `db-integrity-domain.svg` | 음수 수량, 미정의 상태값 차단 |
| 2편 이상현상 | `db-anomaly-insertion.svg` | 삽입 이상 (키 NULL) |
| | `db-anomaly-update.svg` | 갱신 이상 (일부 행만 수정 → 모순) |
| | `db-anomaly-deletion.svg` | 삭제 이상 (마지막 행 삭제 → 정보 소실) |
| 3편 1NF | `db-1nf-atomic.svg` | 원자값 여부 |
| | `db-1nf-decompose.svg` | 반복 그룹 분해 |
| 4편 2NF | `db-fd-basic.svg` | 함수적 종속 기본(결정자→종속자) |
| | `db-2nf-partial.svg` | 부분 함수적 종속 |
| 5편 3NF | `db-3nf-transitive.svg` | 이행적 함수적 종속 |
| 6편 BCNF | `db-bcnf-determinant.svg` | 결정자=후보키 |
| 7편(draft) | `db-keys-natural-surrogate.svg` | 자연키 vs 대리키 (외래키 파급 비교) |

> 같은 방식으로 만든 다른 시리즈 도식: `spring-test-context-cache.svg`, `spring-test-context-cost.svg` (스프링 OOM 글). 동일 디자인 토큰 사용.

---

## 요약
- 본문 개념 도식 = **손으로 짠 SVG** (생성모델 아님). 정확성, 선명함, 검색성, 일관성 때문.
- 팔레트, 폰트, 레이아웃 토큰을 공유해 시리즈 톤을 맞춘다.
- 마크다운 `![서술형 alt](../../assets/*.svg)` 로 임베드, alt는 내용을 문장으로 푼다.
- 히어로/OG 이미지(수채화 PNG)는 이 문서가 아니라 [`hero-image-prompt.md`](./hero-image-prompt.md).
