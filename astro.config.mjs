// @ts-check

import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import { defineConfig } from 'astro/config';
import rehypeKatex from 'rehype-katex';
import remarkMath from 'remark-math';

// https://astro.build/config
export default defineConfig({
	site: 'https://meeemo.net',
	markdown: {
		// 기존 글이 본문에 $를 쓰므로 인라인 $...$ 수식은 끄고 $$ 블록만 수식으로 읽는다.
		remarkPlugins: [[remarkMath, { singleDollarTextMath: false }]],
		// \text{} 안의 한글을 경고 없이 렌더한다.
		rehypePlugins: [[rehypeKatex, { strict: false }]],
	},
	integrations: [
		mdx(),
		sitemap({
			// noindex 처리한 얇은/유틸 페이지는 sitemap에서도 제외한다.
			// /tags/ 메인 탐색 페이지는 유지하고, 개별 /tags/{tag}/ 아카이브만 제외.
			filter: (page) => {
				const path = new URL(page).pathname;
				if (path === '/search/' || path === '/search') return false;
				if (/^\/tags\/[^/]+\/?$/.test(path)) return false;
				return true;
			},
		}),
	],
});
