// @ts-check

import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
	site: 'https://meeemo.net',
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
