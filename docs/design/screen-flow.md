# 화면 흐름도

## 전체 사이트맵

```mermaid
graph TB
    subgraph Public["공개 영역"]
        Home["/ 홈"]
        Posts["/posts 글 목록"]
        PostDetail["/posts/:slug 글 상세"]
        Tags["/tags 태그 목록"]
        TagPosts["/tags/:slug 태그별 글"]
        Categories["/categories 카테고리"]
        CategoryPosts["/categories/:slug 카테고리별 글"]
        Search["/search 검색 결과"]
        About["/about 소개"]
    end

    subgraph Auth["인증 영역"]
        Signin["/signin 로그인"]
        Signup["/signup 회원가입"]
        OAuth["/auth/callback OAuth 콜백"]
    end

    subgraph Admin["어드민 영역"]
        Dashboard["/admin 대시보드"]
        AdminPosts["/admin/posts 글 관리"]
        AdminPostNew["/admin/posts/new 새 글"]
        AdminPostEdit["/admin/posts/:id/edit 글 수정"]
        AdminCategories["/admin/categories 카테고리 관리"]
        AdminTags["/admin/tags 태그 관리"]
        AdminSettings["/admin/settings 설정"]
    end

    subgraph SEO["SEO 엔드포인트"]
        Sitemap["/sitemap.xml"]
        RSS["/rss"]
        Robots["/robots.txt"]
    end

    Home --> Posts
    Home --> Tags
    Home --> Search
    Posts --> PostDetail
    Tags --> TagPosts
    TagPosts --> PostDetail
    Categories --> CategoryPosts
    CategoryPosts --> PostDetail
    Search --> PostDetail

    Signin --> Dashboard
    Dashboard --> AdminPosts
    AdminPosts --> AdminPostNew
    AdminPosts --> AdminPostEdit
```

---

## 사용자 흐름 상세

### 메인 네비게이션

```mermaid
flowchart LR
    subgraph Nav["네비게이션 바"]
        Logo["로고/홈"]
        Menu1["글 목록"]
        Menu2["태그"]
        Menu3["카테고리"]
        SearchIcon["🔍 검색"]
        AuthBtn["로그인/프로필"]
    end

    Logo --> Home["/"]
    Menu1 --> Posts["/posts"]
    Menu2 --> Tags["/tags"]
    Menu3 --> Categories["/categories"]
    SearchIcon --> SearchModal["검색 모달"]
    AuthBtn --> |비로그인| Signin["/signin"]
    AuthBtn --> |로그인| Profile["프로필 드롭다운"]
```

### 홈페이지 → 글 상세

```mermaid
flowchart TD
    Home["홈페이지"]

    subgraph HomeContent["홈 콘텐츠"]
        Hero["히어로 섹션<br/>최신 글 또는 소개"]
        RecentPosts["최근 글 목록<br/>3-6개"]
        PopularTags["인기 태그<br/>태그 클라우드"]
        FeaturedPosts["추천 글<br/>pinned posts"]
    end

    Home --> HomeContent

    RecentPosts --> |클릭| PostDetail["/posts/:slug"]
    FeaturedPosts --> |클릭| PostDetail
    PopularTags --> |클릭| TagPosts["/tags/:slug"]

    subgraph PostDetailContent["글 상세 페이지"]
        Title["제목"]
        Meta["작성일, 카테고리, 조회수"]
        Content["본문 (마크다운 렌더링)"]
        TagList["태그 목록"]
        TOC["목차 (Table of Contents)"]
        Share["공유 버튼"]
        Comments["댓글 (Giscus)"]
        RelatedPosts["관련 글"]
        PrevNext["이전/다음 글"]
    end

    PostDetail --> PostDetailContent
    TagList --> |클릭| TagPosts
    RelatedPosts --> |클릭| PostDetail
    PrevNext --> |클릭| PostDetail
```

### 검색 흐름

```mermaid
flowchart TD
    SearchTrigger["검색 트리거"]

    SearchTrigger --> |키보드 Cmd+K| SearchModal["검색 모달"]
    SearchTrigger --> |검색 아이콘 클릭| SearchModal
    SearchTrigger --> |직접 URL 접근| SearchPage["/search"]

    SearchModal --> |입력| LiveSearch["실시간 검색<br/>(디바운스 300ms)"]
    LiveSearch --> |결과 클릭| PostDetail["/posts/:slug"]
    LiveSearch --> |Enter| SearchPage

    SearchPage --> |필터| Filters["필터 옵션"]

    subgraph Filters
        ByTag["태그별"]
        ByCategory["카테고리별"]
        ByDate["날짜별"]
        SortBy["정렬 (최신/조회수/관련도)"]
    end

    SearchPage --> SearchResults["검색 결과 목록"]
    SearchResults --> |클릭| PostDetail
    SearchResults --> |페이지네이션| SearchPage
```

### 태그/카테고리 탐색

```mermaid
flowchart TD
    Tags["/tags 태그 목록"]
    Categories["/categories 카테고리 목록"]

    subgraph TagsPage["태그 페이지"]
        TagCloud["태그 클라우드<br/>(크기 = 글 수)"]
        TagList["태그 리스트<br/>(알파벳/글 수 정렬)"]
    end

    Tags --> TagsPage
    TagCloud --> |클릭| TagPosts["/tags/:slug"]
    TagList --> |클릭| TagPosts

    subgraph TagPostsPage["태그별 글 목록"]
        TagHeader["#태그명 (n개의 글)"]
        PostGrid["글 카드 그리드"]
        Pagination["페이지네이션"]
    end

    TagPosts --> TagPostsPage
    PostGrid --> |클릭| PostDetail["/posts/:slug"]

    Categories --> CategoryList["카테고리 목록"]
    CategoryList --> |클릭| CategoryPosts["/categories/:slug"]
    CategoryPosts --> PostDetail
```

---

## 인증 흐름 상세

### 로그인 흐름

```mermaid
flowchart TD
    Start["로그인 필요한 액션"]
    Start --> Signin["/signin"]

    subgraph SigninPage["로그인 페이지"]
        EmailForm["이메일/비밀번호 폼"]
        SocialBtns["소셜 로그인 버튼"]
        SignupLink["회원가입 링크"]
        ForgotPwd["비밀번호 찾기"]
    end

    Signin --> SigninPage

    EmailForm --> |제출| ValidateLocal["서버 검증"]
    ValidateLocal --> |성공| CreateSession["세션 생성"]
    ValidateLocal --> |실패| ErrorMsg["에러 메시지 표시"]
    ErrorMsg --> EmailForm

    SocialBtns --> |Google| GoogleOAuth["Google OAuth"]
    SocialBtns --> |Kakao| KakaoOAuth["Kakao OAuth"]
    SocialBtns --> |Naver| NaverOAuth["Naver OAuth"]
    SocialBtns --> |GitHub| GitHubOAuth["GitHub OAuth"]

    GoogleOAuth --> OAuthCallback["/auth/callback/:provider"]
    KakaoOAuth --> OAuthCallback
    NaverOAuth --> OAuthCallback
    GitHubOAuth --> OAuthCallback

    OAuthCallback --> |신규 유저| CreateUser["유저 생성"]
    OAuthCallback --> |기존 유저| CreateSession
    CreateUser --> CreateSession

    CreateSession --> RedirectBack["원래 페이지로 리다이렉트"]

    SignupLink --> Signup["/signup"]
```

### 회원가입 흐름

```mermaid
sequenceDiagram
    participant User as 사용자
    participant Page as 회원가입 페이지
    participant Server as 서버
    participant DB as 데이터베이스
    participant Email as 이메일 서비스

    User->>Page: 회원가입 페이지 접근
    Page->>User: 폼 표시

    User->>Page: 이메일, 비밀번호, 이름 입력
    Page->>Page: 클라이언트 검증 (형식, 길이)

    User->>Page: 제출
    Page->>Server: POST /signup

    Server->>Server: 서버 검증
    Server->>DB: 이메일 중복 확인

    alt 이메일 중복
        DB-->>Server: 중복됨
        Server-->>Page: 400 "이미 가입된 이메일"
        Page-->>User: 에러 표시
    else 신규 이메일
        Server->>Server: 비밀번호 해시
        Server->>DB: INSERT user
        DB-->>Server: OK

        opt 이메일 인증 사용 시
            Server->>Email: 인증 이메일 발송
            Server-->>Page: "이메일을 확인하세요"
        end

        Server-->>Page: Redirect /signin
        Page-->>User: 로그인 페이지로 이동
    end
```

---

## 어드민 흐름 상세

### 어드민 접근 제어

```mermaid
flowchart TD
    Request["어드민 페이지 요청<br/>/admin/*"]

    Request --> CheckSession{"세션 확인"}

    CheckSession --> |세션 없음| RedirectSignin["/signin으로 리다이렉트"]
    CheckSession --> |세션 있음| CheckAdmin{"admin_permission<br/>확인"}

    CheckAdmin --> |false| Forbidden["403 Forbidden<br/>권한 없음 페이지"]
    CheckAdmin --> |true| AllowAccess["접근 허용"]

    AllowAccess --> AdminPage["어드민 페이지 표시"]
```

### 대시보드

```mermaid
flowchart TD
    Dashboard["/admin 대시보드"]

    subgraph DashboardContent["대시보드 콘텐츠"]
        Stats["통계 카드"]
        RecentActivity["최근 활동"]
        QuickActions["빠른 액션"]
    end

    subgraph Stats
        TotalPosts["총 글 수"]
        TotalViews["총 조회수"]
        TodayViews["오늘 조회수"]
        DraftCount["임시저장 수"]
    end

    subgraph QuickActions
        NewPostBtn["+ 새 글 작성"]
        ViewSiteBtn["사이트 보기"]
    end

    Dashboard --> DashboardContent
    NewPostBtn --> AdminPostNew["/admin/posts/new"]
    ViewSiteBtn --> Home["/"]
```

### 글 관리 CRUD

```mermaid
flowchart TD
    AdminPosts["/admin/posts"]

    subgraph PostListPage["글 목록 페이지"]
        SearchFilter["검색 & 필터"]
        PostTable["글 테이블"]
        BulkActions["일괄 작업"]
        Pagination["페이지네이션"]
    end

    AdminPosts --> PostListPage

    subgraph SearchFilter
        SearchInput["검색어 입력"]
        StatusFilter["상태: 전체/공개/비공개/임시저장"]
        CategoryFilter["카테고리 필터"]
    end

    subgraph PostTable
        Columns["제목 | 상태 | 카테고리 | 조회수 | 작성일 | 액션"]
        Row["글 행"]
    end

    subgraph RowActions["행 액션"]
        ViewBtn["보기"]
        EditBtn["수정"]
        DeleteBtn["삭제"]
        PublishBtn["공개/비공개"]
    end

    Row --> RowActions
    ViewBtn --> PostDetail["/posts/:slug"]
    EditBtn --> AdminPostEdit["/admin/posts/:id/edit"]
    DeleteBtn --> DeleteConfirm["삭제 확인 모달"]
    PublishBtn --> TogglePublish["공개 상태 토글"]

    PostListPage --> |+ 새 글| AdminPostNew["/admin/posts/new"]
```

### 글 작성/수정 에디터

```mermaid
flowchart TD
    Editor["글 에디터 페이지"]

    subgraph EditorLayout["에디터 레이아웃"]
        subgraph LeftPanel["좌측 패널 (메인)"]
            TitleInput["제목 입력"]
            MarkdownEditor["마크다운 에디터<br/>(Toast UI Editor)"]
            ImageUpload["이미지 업로드<br/>(드래그 앤 드롭)"]
        end

        subgraph RightPanel["우측 패널 (사이드바)"]
            PublishSettings["발행 설정"]
            CategorySelect["카테고리 선택"]
            TagInput["태그 입력"]
            ThumbnailUpload["썸네일 업로드"]
            SEOPreview["SEO 미리보기"]
        end
    end

    subgraph PublishSettings
        Status["상태: 공개/비공개/임시저장"]
        PublishDate["발행일 설정"]
        Slug["슬러그 편집"]
    end

    Editor --> EditorLayout

    subgraph Actions["액션 버튼"]
        SaveDraft["임시 저장"]
        Preview["미리보기"]
        Publish["발행하기"]
        Cancel["취소"]
    end

    EditorLayout --> Actions
    SaveDraft --> |AJAX| SaveAPI["POST/PUT /admin/posts"]
    Preview --> PreviewModal["미리보기 모달"]
    Publish --> PublishAPI["POST/PUT + published=true"]
    Cancel --> ConfirmCancel["변경사항 있으면 확인"]
```

### 이미지 업로드 흐름

```mermaid
sequenceDiagram
    participant User as 사용자
    participant Editor as 에디터
    participant Server as 서버
    participant Storage as 스토리지 (R2/S3)

    User->>Editor: 이미지 드래그 앤 드롭<br/>또는 붙여넣기
    Editor->>Editor: 파일 검증 (크기, 형식)
    Editor->>User: 업로드 중 표시

    Editor->>Server: POST /admin/upload
    Note over Server: multipart/form-data

    Server->>Server: 이미지 리사이징/최적화
    Server->>Storage: 파일 업로드
    Storage-->>Server: 파일 URL

    Server-->>Editor: {"url": "https://..."}
    Editor->>Editor: 마크다운에 이미지 삽입
    Editor->>User: 이미지 표시
```

---

## 글 상세 페이지 상세

### 페이지 구성

```mermaid
flowchart TB
    subgraph PostPage["글 상세 페이지 /posts/:slug"]
        subgraph Header["헤더 영역"]
            Category["카테고리 뱃지"]
            Title["글 제목"]
            Meta["작성자 · 작성일 · 조회수 · 읽는 시간"]
            Thumbnail["썸네일 이미지"]
        end

        subgraph MainContent["본문 영역"]
            TOC["목차 (사이드바 또는 상단)"]
            Article["마크다운 렌더링된 본문"]
            CodeBlock["코드 하이라이팅"]
            Images["이미지 (lazy loading)"]
        end

        subgraph Footer["푸터 영역"]
            Tags["태그 목록"]
            Share["공유 버튼 (Twitter, Facebook, Link)"]
            LikeBtn["좋아요 버튼"]
        end

        subgraph Navigation["네비게이션"]
            PrevPost["← 이전 글"]
            NextPost["다음 글 →"]
        end

        subgraph Related["관련 콘텐츠"]
            RelatedPosts["관련 글 추천<br/>(같은 태그/카테고리)"]
        end

        subgraph Comments["댓글 영역"]
            Giscus["Giscus 댓글"]
        end
    end

    Header --> MainContent
    MainContent --> Footer
    Footer --> Navigation
    Navigation --> Related
    Related --> Comments
```

### 목차 (TOC) 상호작용

```mermaid
flowchart LR
    subgraph TOC["목차 컴포넌트"]
        H2_1["## 섹션 1"]
        H3_1["### 하위 1.1"]
        H2_2["## 섹션 2"]
        H3_2["### 하위 2.1"]
    end

    H2_1 --> |클릭| ScrollTo1["스크롤 이동"]

    subgraph Behavior["동작"]
        ScrollSpy["스크롤 스파이<br/>(현재 위치 하이라이트)"]
        StickyTOC["고정 목차<br/>(데스크탑 사이드바)"]
        CollapseTOC["접기/펼치기<br/>(모바일)"]
    end
```

---

## 에러 페이지

```mermaid
flowchart TD
    Error["에러 발생"]

    Error --> E404["404 Not Found"]
    Error --> E403["403 Forbidden"]
    Error --> E500["500 Internal Server Error"]

    subgraph E404Page["404 페이지"]
        Msg404["페이지를 찾을 수 없습니다"]
        Search404["검색해 보세요"]
        Home404["홈으로 가기"]
    end

    subgraph E403Page["403 페이지"]
        Msg403["접근 권한이 없습니다"]
        Login403["로그인하기"]
        Home403["홈으로 가기"]
    end

    subgraph E500Page["500 페이지"]
        Msg500["문제가 발생했습니다"]
        Retry500["다시 시도"]
        Report500["문제 신고"]
    end

    E404 --> E404Page
    E403 --> E403Page
    E500 --> E500Page
```

---

## 반응형 레이아웃 상세

### 브레이크포인트

```mermaid
flowchart LR
    subgraph Mobile["📱 모바일<br/>< 640px"]
        M_Nav["햄버거 메뉴"]
        M_Layout["1컬럼"]
        M_Cards["세로 스택"]
        M_TOC["상단 드롭다운 목차"]
        M_Sidebar["하단으로 이동"]
    end

    subgraph Tablet["📱 태블릿<br/>640px - 1024px"]
        T_Nav["축소 네비게이션"]
        T_Layout["2컬럼"]
        T_Cards["2열 그리드"]
        T_TOC["상단 고정"]
        T_Sidebar["우측 축소"]
    end

    subgraph Desktop["🖥️ 데스크탑<br/>> 1024px"]
        D_Nav["전체 네비게이션"]
        D_Layout["3컬럼 (사이드바 포함)"]
        D_Cards["3열 그리드"]
        D_TOC["우측 사이드바 고정"]
        D_Sidebar["우측 사이드바"]
    end

    Mobile --> Tablet --> Desktop
```

### 글 목록 레이아웃

```mermaid
flowchart TB
    subgraph MobileList["모바일 글 목록"]
        M_Card1["카드 1 (전체 너비)"]
        M_Card2["카드 2 (전체 너비)"]
        M_Card3["카드 3 (전체 너비)"]
    end

    subgraph DesktopList["데스크탑 글 목록"]
        direction LR
        D_Card1["카드 1"]
        D_Card2["카드 2"]
        D_Card3["카드 3"]
    end
```

---

## 페이지별 SEO 메타

| 페이지 | title | description | og:image |
|--------|-------|-------------|----------|
| 홈 | 블로그명 | 블로그 소개 | 기본 OG 이미지 |
| 글 상세 | 글 제목 \| 블로그명 | 글 요약 | 글 썸네일 |
| 태그 | #태그명 \| 블로그명 | 태그 설명 | 기본 이미지 |
| 검색 | 검색: 키워드 \| 블로그명 | 검색 결과 | 기본 이미지 |
| 어드민 | (noindex) | - | - |