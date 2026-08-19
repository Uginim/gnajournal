import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';
import { CATEGORY_SLUGS } from './consts';

const blog = defineCollection({
	loader: glob({ base: './src/content/blog', pattern: '**/*.{md,mdx}' }),
	schema: ({ image }) =>
		z.object({
			title: z.string(),
			description: z.string(),
			pubDate: z.coerce.date(),
			updatedDate: z.coerce.date().optional(),
			heroImage: z.optional(image()),
			// 소셜 카드(og:image, twitter:image)용 이미지.
			// heroImage 를 SVG 로 두면 X, 페이스북, 카카오톡, 슬랙이 렌더하지 못한다.
			// 그래서 화면에 보이는 히어로는 SVG 로 두고, 소셜 카드는 래스터를 따로 준다.
			// 생략하면 heroImage 를 그대로 쓴다.
			ogImage: z.optional(image()),
			tags: z.array(z.string()).default([]),
			draft: z.boolean().default(false),
			// 카테고리는 색인 대상 페이지를 만든다. 공개하는 글에는 반드시 있어야 하며,
			// 누락 시 /categories/ 빌드에서 에러로 잡는다.
			// 아직 정리하지 않은 초안까지 강제하지 않으려고 스키마에서는 optional로 둔다.
			category: z.enum(CATEGORY_SLUGS).optional(),
		}),
});

export const collections = { blog };
