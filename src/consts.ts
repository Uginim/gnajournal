export const SITE_TITLE = '그나저나 메모';
export const SITE_DESCRIPTION = '개발하다 궁금했던 것들을 직접 확인하고 기록합니다. 백엔드, 데이터베이스 그리고 가끔은 그 밖의 관심사를 다룹니다.';

// 카테고리 단일 출처.
// 글의 frontmatter `category`는 여기 slug 중 하나를 쓴다.
// 태그와 달리 카테고리 페이지는 색인 대상이므로, 목록만 있는 얇은 페이지가
// 되지 않도록 각 카테고리에 소개 문단(intro)을 반드시 둔다.
export const CATEGORIES = [
	{
		slug: 'database',
		name: '데이터베이스',
		// meta description용 한 문장.
		description:
			'정규화 이론부터 쿼리 실행 계획까지, 데이터를 어떻게 나누고 어떻게 꺼낼지 다룬 글 모음입니다.',
		// 카테고리 페이지 본문에 노출되는 소개 문단.
		intro:
			'테이블을 어떻게 나눌지, 나눈 데이터를 어떻게 다시 꺼낼지에 대한 기록입니다. 정규화는 정의를 외우는 것보다 어떤 이상현상을 막으려고 그 규칙이 생겼는지를 따라가는 편이 이해가 빨랐습니다. 쿼리 쪽은 널리 알려진 통념이 실제 실행 계획과 맞는지 직접 실행해 확인한 글이 많습니다. MySQL, MariaDB, Oracle을 다룹니다.',
	},
	{
		slug: 'backend',
		name: '백엔드와 API',
		description:
			'Spring과 JPA로 서버를 만들며 마주친 문제와 원인을 추적한 글, 그리고 HTTP API 설계에 대한 글 모음입니다.',
		intro:
			'프레임워크가 대신 해주는 일이 예상과 다르게 동작할 때, 어디까지 파고들어야 원인이 나오는지를 다룹니다. JPA와 Hibernate에서 겪은 문제, Spring 테스트가 CI에서만 죽는 이유 같은 것들입니다. 서버가 밖으로 내보내는 약속인 HTTP API 설계도 여기에 함께 두었습니다.',
	},
	{
		slug: 'devtools',
		name: '개발 도구',
		description:
			'개발에 쓰는 도구가 실제로 어떻게 동작하는지 직접 확인한 글 모음입니다.',
		intro:
			'도구의 문서에 적히지 않은 동작이나, 설정 하나를 바꿨을 때 무엇이 달라지는지를 직접 실행해 확인한 기록입니다. 동작 방식을 모르면 비용이나 시간이 어디서 새는지 짚을 수 없다는 게 대체로 출발점이었습니다.',
	},
] as const;

export type CategorySlug = (typeof CATEGORIES)[number]['slug'];

export const CATEGORY_SLUGS = CATEGORIES.map((c) => c.slug) as [CategorySlug, ...CategorySlug[]];

export function getCategory(slug: string) {
	return CATEGORIES.find((c) => c.slug === slug);
}
