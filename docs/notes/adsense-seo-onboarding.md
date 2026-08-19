# AdSense 온보딩과 사이트 품질 정비 학습 노트

이 문서는 이 블로그(meeemo.net)에 Google AdSense를 붙이면서 정리한 개념과 작업을 학습용으로 남긴 것입니다. 특정 시점의 작업 기록이자, 같은 일을 다시 할 때 참고할 개념 노트입니다.

## 1. AdSense는 두 단계로 나뉜다

AdSense를 처음 붙일 때 흔히 하나로 뭉뚱그려 생각하지만, 실제로는 성격이 다른 두 단계입니다.

1. **소유권 확인(site verification)**: "이 사이트가 정말 당신 것이냐"를 확인합니다. 페이지에 지정한 코드나 파일이 실제로 올라와 있는지 크롤러가 확인할 뿐입니다. 콘텐츠 품질과는 무관합니다.
2. **사이트 검토(광고 심사)**: 소유권 확인 뒤에 이어지는 단계로, 콘텐츠 품질과 정책 준수를 사람과 시스템이 검토합니다. 며칠 걸리고, 신청자가 더 할 일은 없습니다.

두 단계를 구분하는 것이 중요합니다. "확인 불가"가 뜬다면 그것은 대개 콘텐츠 문제가 아니라 코드가 프로덕션에 안 올라간 문제입니다.

## 2. 소유권 확인 방법 세 가지

확인 화면에서 세 가지 중 하나를 고릅니다.

- **애드센스 코드 스니펫**: `<script>`를 모든 페이지 `<head>`에 넣습니다. 이 코드는 소유권 확인용이자 실제 광고를 띄우는 코드이기도 합니다. 즉 한 번 넣으면 확인과 광고 게재 준비를 겸합니다.
- **Ads.txt 스니펫**: 확인은 되지만 광고 코드는 별도로 넣어야 합니다.
- **메타 태그**: 확인 전용입니다. 나중에 지우고 광고 코드로 교체하게 됩니다.

세 방법 중 코드 스니펫이 가장 실용적입니다. 확인 뒤에 별도 작업이 없기 때문입니다.

정적 사이트 생성기(여기서는 Astro)에서는 모든 페이지가 공통 `<head>` 컴포넌트를 씁니다. 그래서 스니펫을 그 컴포넌트 한 곳에만 넣으면 전 페이지에 적용됩니다. 이 저장소에서는 `src/components/BaseHead.astro`가 그 역할을 합니다.

## 3. Cloudflare Pages 배포 함정: 프로덕션 vs 프리뷰

이번에 가장 크게 헤맨 부분입니다. 소유권 확인이 계속 실패했는데, 원인은 콘텐츠가 아니라 배포가 프로덕션에 반영되지 않은 것이었습니다.

이 프로젝트는 Cloudflare Pages를 **Direct Upload** 방식으로 씁니다. GitHub 연동이 아니라 `wrangler`로 빌드 결과물을 직접 올립니다. 배포 명령은 다음과 같습니다.

```bash
npm run build
npx wrangler pages deploy dist --project-name gnajournal --commit-dirty=true
```

여기서 함정은 **브랜치**입니다. `--branch`를 생략하면 `wrangler`가 현재 git 브랜치명을 배포 브랜치로 사용합니다. Cloudflare Pages는 배포 브랜치가 프로덕션 브랜치(`main`)와 같으면 Production, 다르면 Preview로 처리합니다.

- `main`에서 배포하면 Production이 되어 커스텀 도메인(meeemo.net)이 갱신됩니다.
- feature 브랜치에서 같은 명령을 쓰면 Preview 배포가 되고, 커스텀 도메인은 갱신되지 않습니다.

그래서 feature 브랜치에서 작업할 때는 프로덕션 반영에 `--branch main`이 필요합니다.

```bash
npx wrangler pages deploy dist --project-name gnajournal --branch main --commit-dirty=true
```

### 배포 검증을 단발 요청으로 단정하지 않기

배포 직후 몇 초에서 몇십 초 동안은 Cloudflare의 여러 엣지 지점에 전파되는 과도기라, 같은 URL을 연달아 요청해도 새 버전과 옛 버전이 번갈아 나올 수 있습니다. 그래서 검증은 다음 두 가지를 함께 봅니다.

- 배포 환경을 권위 있게 확인: `npx wrangler pages deployment list --project-name gnajournal`의 Environment 열이 Production인지 본다.
- 배포 원본 URL(`<id>.gnajournal.pages.dev`)로 교차 확인: 이 URL은 도메인 전파와 무관하게 그 배포물을 직접 보여준다.

단발 `curl` 한 번으로 "라이브 반영됐다"고 단정하지 않는 것이 교훈입니다.

## 4. 사이트 검토 대비: 얇은 URL 정리

콘텐츠 자체가 충분하더라도, 검색엔진에 노출되는 얇은 페이지가 많으면 사이트 품질 신호가 흐려집니다. 두 종류를 정리했습니다.

### 검색 페이지와 개별 태그 아카이브에 noindex

내부 검색 페이지(`/search/`)와 글 한두 개짜리 개별 태그 페이지(`/tags/{tag}/`)는 사용자에게는 유용하지만, 검색엔진이 독립된 콘텐츠로 색인할 이유는 없습니다. 이런 페이지의 `<head>`에 다음을 넣습니다.

```html
<meta name="robots" content="noindex, follow">
```

`noindex`는 색인하지 말라는 뜻이고, `follow`는 페이지 안의 링크는 따라가도 좋다는 뜻입니다.

반면 태그 목록 메인 페이지(`/tags/`)는 사이트 전체 탐색 기능이라 색인을 유지합니다.

이 저장소에서는 공통 `BaseHead.astro`에 `noindex` prop을 추가하고, `search.astro`와 `tags/[tag].astro`에서 그 prop을 넘기는 방식으로 구현했습니다. 한 곳에 로직을 두고 재사용하는 편이 각 페이지에 태그를 복제하는 것보다 낫습니다.

### robots.txt로 막으면 안 되는 이유

중요한 함정이 있습니다. `noindex`를 검색엔진이 읽으려면 그 페이지를 크롤링할 수 있어야 합니다. `robots.txt`로 `/search/`를 아예 차단하면, 크롤러가 페이지를 못 읽어서 `noindex`도 못 읽습니다. 그러면 URL 자체는 검색 결과에 남을 수 있습니다.

정리하면 다음과 같습니다.

- 크롤링: 허용
- 색인: noindex

즉 `robots.txt` 차단과 `noindex`는 같이 쓰면 안 됩니다.

### sitemap에서 noindex 페이지 제외

sitemap에는 검색 결과에 표시하고 싶은 대표 URL만 넣는 것이 원칙입니다. `noindex` 처리한 페이지를 sitemap에 넣는 것은 모순이므로 제외합니다.

이 저장소는 `@astrojs/sitemap`을 쓰며, `astro.config.mjs`에 `filter` 함수를 넣어 `/search/`와 개별 `/tags/{tag}/`를 걸러냈습니다. `/tags/` 메인은 남깁니다.

```js
sitemap({
  filter: (page) => {
    const path = new URL(page).pathname;
    if (path === '/search/' || path === '/search') return false;
    if (/^\/tags\/[^/]+\/?$/.test(path)) return false; // /tags/{tag}/ 제외, /tags/ 는 유지
    return true;
  },
})
```

## 5. 신뢰 신호(E-E-A-T)

Google은 "누가 썼고, 왜 믿을 만한가"를 콘텐츠 평가 요소로 봅니다. 두 가지를 보강했습니다.

### 작성자 바이라인

글 상단 날짜 옆에 작성자(kimenugi)를 표시하고 소개 페이지(`/about/`)로 링크했습니다. 사람 눈에 보이는 신뢰 정보입니다. `BlogPost.astro` 레이아웃 한 곳에 넣어 모든 글에 적용됩니다.

참고로 이 저장소의 글쓰기 스타일은 가운뎃점 나열을 금지합니다. 그래서 날짜와 작성자 사이의 구분점은 소스에 가운뎃점 문자를 직접 넣지 않고, CSS의 `content: '\00B7'` 이스케이프로 렌더했습니다. 화면에는 점으로 보이지만 소스 파일에는 그 문자가 없습니다.

### Article(BlogPosting) JSON-LD 구조화 데이터

작성자 바이라인이 사람 눈에 보이는 버전이라면, JSON-LD는 같은 정보를 기계(검색엔진)에게 알려주는 버전입니다. 페이지에 아래 같은 스크립트를 넣어, 제목과 게시일, 작성자, 대표 이미지 같은 정보를 본문에서 추측하게 두지 않고 직접 선언합니다.

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "글 제목",
  "description": "글 요약",
  "datePublished": "2026-07-15T...",
  "image": "https://meeemo.net/_astro/....png",
  "author": { "@type": "Person", "name": "kimenugi", "url": "https://meeemo.net/about/" },
  "mainEntityOfPage": "https://meeemo.net/blog/..."
}
</script>
```

이 저장소에서는 `BlogPost.astro` 레이아웃에서 프론트매터(제목, 설명, 게시일, 대표 이미지)와 작성자로 이 객체를 자동 생성합니다. 글마다 손댈 필요가 없습니다. `heroImage`가 없는 글은 `image` 필드를 생략합니다.

주의할 점이 두 가지 있습니다.

- 이것은 SEO 보강이지 AdSense 승인의 필수 요건은 아닙니다.
- 구조화 데이터를 넣는다고 검색 결과에 리치 결과가 반드시 표시되는 것은 아닙니다. 표시 여부는 Google이 자체 판단합니다.

## 6. AdSense: 필수 vs 선택 정리

| 항목 | 성격 |
| --- | --- |
| 소유권 확인 코드 스니펫 | 확인 단계 필수 |
| 고품질 독창적 콘텐츠 | 검토 단계 핵심 |
| 개인정보처리방침(광고 쿠키 고지 포함) | 사실상 필수 |
| 소개/연락처 페이지 | 신뢰 요소 |
| 검색/태그 상세 noindex, sitemap 정리 | 품질 신호 보강(권장) |
| 작성자 바이라인 | 신뢰 신호(권장) |
| Article JSON-LD | SEO 보강(선택) |
| ads.txt | 승인 이후 설정 |
| 유럽 방문자 CMP | 해당 지역 광고 시 필요 |

Google은 특정 글 개수를 요구하지 않습니다. 짧은 글을 억지로 늘리기보다, 깊이 있는 글과 명확한 탐색 구조를 갖추는 편이 낫습니다.

## 7. 참고 링크

- AdSense 자격 요건: https://support.google.com/adsense/answer/9724?hl=ko
- 사이트 준비 상태: https://support.google.com/adsense/answer/7299563?hl=ko
- 개인정보처리방침 요구 콘텐츠: https://support.google.com/adsense/answer/1348695?hl=ko
- robots.txt 소개: https://developers.google.com/search/docs/crawling-indexing/robots/intro
- sitemap 만들기: https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap
- Article 구조화 데이터: https://developers.google.com/search/docs/appearance/structured-data/article
- 사람 중심 콘텐츠 가이드: https://developers.google.com/search/docs/fundamentals/creating-helpful-content
