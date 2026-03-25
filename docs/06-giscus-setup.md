# Giscus 댓글 설정 가이드

Giscus는 GitHub Discussions 기반의 무료 댓글 시스템입니다.

## 사전 조건

- GitHub 계정
- 공개(public) GitHub 저장소

## 1단계: 저장소 준비

1. GitHub에 블로그용 저장소 생성 (또는 기존 저장소 사용)
2. 저장소 Settings > General > Features 에서 **Discussions** 체크

## 2단계: Giscus 앱 설치

1. https://github.com/apps/giscus 접속
2. "Install" 클릭
3. 블로그 저장소를 선택하여 설치

## 3단계: 설정 값 생성

1. https://giscus.app/ko 접속
2. 저장소 입력 (예: `username/repo-name`)
3. 페이지-Discussions 매핑: **pathname** 선택 (권장)
4. Discussion 카테고리: **Announcements** 선택 (권장)
5. 페이지 하단에 생성된 설정 값 확인:
   - `data-repo`
   - `data-repo-id`
   - `data-category`
   - `data-category-id`

## 4단계: 코드 적용

`src/components/Giscus.astro`에서 4개의 값을 교체:

```javascript
const repo = 'username/repo-name';       // data-repo 값
const repoId = 'R_xxxxx';               // data-repo-id 값
const category = 'Announcements';        // data-category 값
const categoryId = 'DIC_xxxxx';         // data-category-id 값
```

## 확인

설정 완료 후 블로그 글 하단에 댓글 입력란이 표시됩니다.
- 댓글을 달려면 GitHub 로그인 필요
- 댓글은 GitHub Discussions에 저장됨
- 다크모드 전환 시 댓글 테마도 자동 변경

## 댓글 관리

- GitHub 저장소 > Discussions 탭에서 모든 댓글을 관리할 수 있습니다
- 스팸 댓글 삭제, 고정, 잠금 등 GitHub Discussions의 모든 기능 사용 가능
