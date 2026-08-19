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

## Writing Style (blog posts and chat replies)

Full rules: [`docs/writing-style.md`](docs/writing-style.md). Terminology: [`docs/writing-terms.md`](docs/writing-terms.md).

`.claude/hooks/blog-style-check.sh` blocks these automatically, **in blog markdown and in chat replies alike**. Knowing them up front avoids a rejected turn:

- No em dash (`—`). Use a colon in titles, a comma mid-sentence, or split the sentence.
- No interpunct (`·`) for lists. Use commas or write it out.
- No period inside a bold label (`**label.**`). Use the colon form (`**label**: text`).
- Keep the polite `~합니다` ending in Korean prose.

Judgment calls the hook cannot catch, and the skills that check them:

| Concern | Skill | When |
|---|---|---|
| Do the headings tell the story on their own? | `toc-flow-review` | after writing or restructuring any multi-heading post |
| Does each sentence belong where it is? | `blog-flow-check` | right after a draft, and after large edits |
| Tone, translationese, overclaiming | `blog-tone-check` | before publishing |

Two rules that cost a rework this session:

- **Heading format is matched within the post, not across the repo.** Copying another post's convention makes the headings read as machine-written in the post you are editing.
- **Never state an unverified result.** Numbers, command output, and error messages in a post must come from an actual run. Reproduce it, then paste what came back.

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

