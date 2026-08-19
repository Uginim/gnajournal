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
- Keep imports sorted; remove unused code. No linters/formatters configured, so follow Astro + TypeScript defaults.

## Writing Style

**Read [`docs/writing-style.md`](docs/writing-style.md) before writing or editing any blog
content.** It is the single source for sentence rules, the banned list, heading grammar,
citation rules, and which check skill to run when. Do not restate its rules elsewhere;
a partial copy drifts and then contradicts it.

Terminology: [`docs/writing-terms.md`](docs/writing-terms.md). Look up English technical
terms there instead of inventing a Korean translation.

`.claude/hooks/blog-style-check.sh` blocks the mechanically detectable subset on its own,
**in blog markdown saves and in chat replies alike**. Being blocked costs a turn, so read
the doc up front rather than learning the rules from rejections.

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

This project uses **Direct Upload**, not Git integration. `git push` does not deploy.
Production deploys are manual and must be run from a completed `npm run build`.

- Production: `npx wrangler pages deploy dist --project-name gnajournal --branch main`
- Preview: `npm run build && npx wrangler pages dev dist`
- Secrets: `npx wrangler pages project secret put <NAME>`

### `--branch main` is required

The Pages production branch is `main`. Deploying from a feature branch without
`--branch main` picks up the git branch name and creates a **Preview** deployment,
which never reaches the custom domain (meeemo.net). Confirm afterwards:

```bash
npx wrangler pages deployment list --project-name gnajournal | head -5   # Environment must read Production
```

### Compare sitemaps before deploying

A file that exists only in the working tree (untracked) is live today but will
**disappear** from the next deploy built off a clean checkout. On 2026-08-19 this
nearly turned an indexed post URL into a 404.

Run this before every production deploy. Any output means those URLs are about to vanish:

```bash
curl -s https://meeemo.net/sitemap-0.xml | grep -o '<loc>[^<]*' | sed 's|<loc>||' | sort > /tmp/live.txt
grep -o '<loc>[^<]*' dist/sitemap-0.xml   | sed 's|<loc>||' | sort > /tmp/new.txt
comm -23 /tmp/live.txt /tmp/new.txt
```

If URLs are missing, find the untracked source and commit it before deploying:

```bash
git status --porcelain src/content/blog src/assets
```

### Verify against the deployment URL, not just the domain

Right after a deploy, Cloudflare POP propagation can serve the old version from the
custom domain for a few seconds (`cf-cache-status: DYNAMIC`). A 404 on a brand new
page is usually propagation, not a broken build. Cross-check with the deployment URL
that wrangler prints (`https://<id>.gnajournal.pages.dev`) before investigating.

