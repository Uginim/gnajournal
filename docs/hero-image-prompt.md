# 히어로/OG 이미지 생성 프롬프트 (그나저나 메모)

블로그 히어로 이미지를 **일관된 수채화 마스코트 톤**으로, **OG 표준 비율 1.91:1 (1200×630)** 에 맞춰 생성하기 위한 프롬프트 템플릿.

- 이미지 생성 모델(Gemini / ChatGPT 등)에 붙여 넣고, `«...»` 부분만 글마다 교체한다.
- 히어로는 `1200×630`(또는 2배 `2400×1260`)로 만들면 히어로·OG 양쪽에 크롭 없이 들어간다.
- **금지어**: 책등·문구에 `마스터`, `정복`, `완벽`, `전문가` 등 도달·결과 보장 표현 금지(게시 콘텐츠 과장 금지 규칙).

---

## 공통 프롬프트 (스타일·레이아웃 고정)

```
A warm, soft watercolor illustration, children's-book style, cozy and cute.
ASPECT RATIO: wide landscape banner, 1.91:1 (1200 x 630 px). Keep all text and the
sheep within a safe margin so nothing is cut at the edges.

SCENE (keep identical every time for consistency):
- A fluffy white cartoon sheep sitting at a light wooden desk on the RIGHT, holding a
  pencil, gentle smile, a gray laptop with a tiny sheep sticker, a coffee mug, and a
  stack of books with Korean spine labels on the far right.
- LEFT/back: a bright window with greenery, potted plants, a folded "JPA" newspaper.
- Cream / warm-beige background. Soft brown outlines. Rounded bold Korean lettering.
- TOP: a parchment scroll banner. Brown rounded tag with the series label, big bold
  title below, small leaf sprigs beside the subtitle.
- A thought/speech bubble near the sheep's head (top-right).

TEXT TO RENDER (Korean, exact):
- Series tag:  데이터베이스 정규화 (N)
- Title:       «제목»
- Subtitle:    «부제»
- Panels (3 cards on the parchment):  «패널1» / «패널2» / «패널3»
- Bottom "분해" section:  Before «...»  →  After «...»  + green check "중복 감소"
- Speech bubble:  «말풍선»
- Book spines (right): «책등1» / «책등2» / «책등3»

Clean, uncluttered, friendly. No watermark.
```

> 모델이 1.91:1을 정확히 안 지키면, 나온 그림을 1200×630으로 크롭한다.
> (중요 요소는 가운데 안전영역에 두도록 위 프롬프트에 명시돼 있음)

---

## 편별 채움값

### 5편 — 제3정규형 (3NF)
```
- Series tag: 데이터베이스 정규화 (5)
- Title: 제3정규형 (3NF)
- Subtitle: 이행적 함수적 종속 제거
- Panels: [핵심 개념] 이행적 함수적 종속 (키 → A → B) / [예시] 직원ID → 부서ID → 부서명 / [3NF 핵심] 비주요 속성은 키에만 직접 의존
- Bottom: Before 직원(직원ID, 직원명, 부서ID, 부서명, 부서장) → After 직원(직원ID, 직원명, 부서ID) + 부서(부서ID, 부서명, 부서장) + 중복 감소
- 말풍선: 거쳐서 의존하면 분리!
- 책등: 3NF / 이행적 종속 / 함수적 종속
```

### 6편 — 보이스-코드 정규형 (BCNF)
```
- Series tag: 데이터베이스 정규화 (6)
- Title: 보이스-코드 정규형 (BCNF)
- Subtitle: 모든 결정자를 후보키로
- Panels: [핵심 개념] 결정자 · 후보키 / [예시] 교수 → 과목 (결정자가 후보키 아님) / [BCNF 핵심] 모든 비자명 종속의 결정자 = 슈퍼키
- Bottom: Before 수강(학생, 과목, 교수) → After 수강(학생, 교수) + 교수과목(교수, 과목) + 중복 감소
- 말풍선: 결정자가 키가 아니면 분리!
- 책등: BCNF / 결정자 / 후보키
```

### (참고) 작성된 편
- 1편 데이터 무결성과 키 / 2편 이상현상 / 3편 1NF / 4편 2NF — 히어로 이미지 적용됨.
- 7편 자연키와 대리키(현재 draft) / 8편 제4·제5정규형 / 9편 정규화 절차와 역정규화 — 추후 같은 형식으로 채워 사용.

---

## 적용 방법
1. 위 프롬프트로 1200×630 PNG 생성(필요 시 크롭).
2. `src/assets/db-normalization-<n>-<slug>.png` 로 저장.
3. 해당 글 frontmatter `heroImage` 경로 지정(이미 지정돼 있으면 파일만 교체).
4. `npm run build` 후 `npx wrangler pages deploy dist --project-name gnajournal --commit-dirty=true`.
