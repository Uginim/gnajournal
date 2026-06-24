# Repository Guidelines

## Project Structure & Module Organization
- `src/pages/`: Route-based `.astro` pages (blog, tags, rss, index).
- `src/components/`: Reusable UI components (PascalCase).
- `src/layouts/`: Page wrappers like `BlogPost.astro`.
- `src/content/`: Content collections for posts (`.md`/`.mdx`).
- `src/assets/` and `public/`: Images and static files (`public` served as-is).
- `docs/` and `tutorial/`: Project docs and examples.
- `dist/`: Production build output (do not edit).
- Config: `astro.config.mjs`, `tsconfig.json`, `src/content.config.ts`; scripts in `package.json`.

## Build, Test, and Development Commands
- `npm i`: Install dependencies (Node >= 22.12.0).
- `npm run dev`: Start Astro dev server at `http://localhost:4321`.
- `npm run build`: Build site into `dist/`.
- `npm run preview`: Serve the built `dist/` locally.
- `npm run astro -- check`: Type and Astro diagnostics.
- `npm run astro -- sync`: Regenerate content types after schema/content changes.

## Coding Style & Naming Conventions
- Indentation: 2 spaces; UTF-8; LF endings.
- Languages: Astro, TypeScript, Markdown/MDX. Prefer strict, typed component props.
- Naming: Components PascalCase (`Header.astro`), pages/routes kebab-case (`blog/index.astro`), content slugs kebab-case, assets lowercase-with-hyphens.
- Keep imports sorted; remove unused code. No linters/formatters configured—follow Astro + TypeScript defaults.

## Testing Guidelines
- No tests yet. Manually verify builds, pages, tag filtering, search, and `/rss.xml`.
- Optional setup: `npm i -D vitest @vitest/coverage-v8 @playwright/test` and `npx playwright install`.
- Suggested structure: `src/**/__tests__` (Vitest), `tests/` (Playwright).
- Run examples: `npx vitest run --coverage`, `npx playwright test`.

## Commit & Pull Request Guidelines
- Commits: imperative, concise (e.g., "Add header", "Fix RSS dates").
- PRs: include summary, linked issues, screenshots for UI changes, steps to verify locally, and notes on content schema changes.
- Checklist: build and preview pass; affected pages/screenshots attached; `npm run astro -- sync` after schema updates; RSS/tags/search still function; docs updated.

## Security & Configuration Tips
- Store secrets in env vars; never commit `.env*`. Read via `import.meta.env`.
- Deployment uses static `dist/`. Cloudflare Pages supported via Wrangler in `.wrangler/`.

## Cloudflare Deploy (Wrangler)
- Deploy: `npx wrangler pages deploy dist --project-name <project>`.
- Preview: `npm run build && npx wrangler pages dev dist`.
- Secrets: `npx wrangler pages project secret put <NAME>`.

