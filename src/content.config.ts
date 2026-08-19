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
			tags: z.array(z.string()).default([]),
			draft: z.boolean().default(false),
			// 카테고리는 색인 대상 페이지를 만든다. 공개하는 글에는 반드시 있어야 하며,
			// 누락 시 /categories/ 빌드에서 에러로 잡는다.
			// 아직 정리하지 않은 초안까지 강제하지 않으려고 스키마에서는 optional로 둔다.
			category: z.enum(CATEGORY_SLUGS).optional(),
		}),
});

export const collections = { blog };
