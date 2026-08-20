// PR 이 사이트 배포에 영향을 주는지 판정하고, 변경된 페이지 목록과
// sitemap 안전검사 결과를 마크다운으로 출력한다.
//
//   node scripts/pr-deploy-report.mjs <변경파일목록파일> [프리뷰URL]
//
// 변경파일목록파일: 한 줄에 하나씩 저장소 상대 경로.
// 프리뷰URL: 있으면 변경된 페이지를 프리뷰 절대 주소로 링크한다.
//
// 이 스크립트는 판정과 출력만 한다. 배포는 하지 않는다.

import { readFileSync, existsSync } from 'node:fs';

const LIVE_SITEMAP = 'https://meeemo.net/sitemap-0.xml';
const REPO = process.env.GITHUB_REPOSITORY ?? 'Uginim/gnajournal';
const BRANCH = process.env.PR_HEAD_REF ?? 'main';

const [listPath, previewUrl] = process.argv.slice(2);
if (!listPath) {
	console.error('usage: pr-deploy-report.mjs <changed-files.txt> [preview-url]');
	process.exit(2);
}

const changed = readFileSync(listPath, 'utf8')
	.split('\n')
	.map((s) => s.trim())
	.filter(Boolean);

// 빌드 결과물에 들어가는 경로. 여기가 바뀌면 배포가 필요하다.
const AFFECTS_BUILD = [
	/^src\//,
	/^public\//,
	/^astro\.config\.mjs$/,
	/^package(-lock)?\.json$/,
];

const needsDeploy = changed.some((f) => AFFECTS_BUILD.some((re) => re.test(f)));

// 변경된 소스 파일을 사이트 경로로 바꾼다.
function toRoute(file) {
	let m = file.match(/^src\/content\/blog\/(.+)\.(md|mdx)$/);
	if (m) return `/blog/${m[1]}/`;

	m = file.match(/^src\/pages\/(.+)\.astro$/);
	if (m) {
		let p = m[1];
		if (p === 'index') return '/';
		if (p.endsWith('/index')) return `/${p.slice(0, -'/index'.length)}/`;
		// [...slug] 같은 동적 라우트는 개별 경로를 알 수 없다.
		if (p.includes('[')) return null;
		return `/${p}/`;
	}
	return null;
}

const routes = [...new Set(changed.map(toRoute).filter(Boolean))].sort();
const docs = changed.filter((f) => /^docs\/.+\.md$/.test(f)).sort();

// draft 인 글은 프로덕션 빌드에 안 들어간다. 링크를 걸면 404 가 되므로 표시만 한다.
function isDraft(file) {
	if (!existsSync(file)) return false;
	const head = readFileSync(file, 'utf8').slice(0, 800);
	return /^draft:\s*true/m.test(head);
}
const draftRoutes = new Set(
	changed.filter((f) => /^src\/content\/blog\//.test(f) && isDraft(f)).map(toRoute).filter(Boolean),
);

// sitemap 안전검사: 라이브에 있던 URL 이 새 빌드에서 사라지는지 본다.
async function sitemapDiff() {
	if (!existsSync('dist/sitemap-0.xml')) {
		return { ok: false, reason: 'dist/sitemap-0.xml 이 없다. 빌드가 먼저 필요하다.' };
	}
	let liveXml;
	try {
		const res = await fetch(LIVE_SITEMAP, { headers: { 'user-agent': 'pr-deploy-report' } });
		if (!res.ok) return { ok: false, reason: `라이브 sitemap 응답 ${res.status}` };
		liveXml = await res.text();
	} catch (e) {
		return { ok: false, reason: `라이브 sitemap 요청 실패: ${e.message}` };
	}
	const locs = (xml) => new Set([...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]));
	const live = locs(liveXml);
	const next = locs(readFileSync('dist/sitemap-0.xml', 'utf8'));
	const missing = [...live].filter((u) => !next.has(u)).sort();
	const added = [...next].filter((u) => !live.has(u)).sort();
	return { ok: true, liveCount: live.size, nextCount: next.size, missing, added };
}

const out = [];
out.push('## 배포 영향 판정');
out.push('');

if (!needsDeploy) {
	out.push('**배포 불필요.** 빌드 결과물에 들어가는 파일이 바뀌지 않았습니다.');
	out.push('');
	out.push('`src/`, `public/`, `astro.config.mjs`, `package.json` 이 바뀔 때만 배포가 필요합니다.');
	out.push('');
} else {
	out.push('**배포 필요.** 빌드 결과물에 들어가는 파일이 바뀌었습니다.');
	out.push('');

	if (routes.length) {
		out.push('### 변경된 페이지');
		out.push('');
		for (const r of routes) {
			if (draftRoutes.has(r)) {
				out.push(`- \`${r}\` (draft, 프로덕션 빌드에서 제외됨)`);
			} else if (previewUrl) {
				out.push(`- [${r}](${previewUrl.replace(/\/$/, '')}${r})`);
			} else {
				out.push(`- \`${r}\``);
			}
		}
		out.push('');
	}

	const diff = await sitemapDiff();
	out.push('### sitemap 안전검사');
	out.push('');
	if (!diff.ok) {
		out.push(`검사하지 못했습니다: ${diff.reason}`);
	} else if (diff.missing.length) {
		out.push(`> **경고: 라이브에 있던 URL ${diff.missing.length}개가 이 빌드에서 사라집니다.**`);
		out.push('>');
		out.push('> 색인된 주소가 404 가 될 수 있습니다. 머지 전에 원인을 확인하세요.');
		out.push('> 흔한 원인은 저장소에 없는 파일(untracked)이 라이브에만 있는 경우입니다.');
		out.push('');
		for (const u of diff.missing) out.push(`- \`${u}\``);
		out.push('');
	} else {
		out.push(`사라지는 URL 없음. 라이브 ${diff.liveCount}개, 이 빌드 ${diff.nextCount}개.`);
		out.push('');
		if (diff.added.length) {
			out.push('새로 추가되는 URL:');
			out.push('');
			for (const u of diff.added) out.push(`- \`${u}\``);
			out.push('');
		}
	}

	out.push('### 프리뷰');
	out.push('');
	if (previewUrl) {
		out.push(`${previewUrl}`);
	} else {
		out.push('설정되지 않았습니다. 저장소 Secret 에 `CLOUDFLARE_API_TOKEN` 을 넣으면');
		out.push('이 자리에 프리뷰 주소와 변경된 페이지의 직접 링크가 나옵니다.');
	}
	out.push('');
}

if (docs.length) {
	out.push('### 변경된 저장소 문서');
	out.push('');
	out.push('사이트에 배포되지 않는 문서입니다. GitHub 렌더 화면으로 봅니다.');
	out.push('');
	for (const d of docs) {
		out.push(`- [${d}](https://github.com/${REPO}/blob/${BRANCH}/${d})`);
	}
	out.push('');
}

console.log(out.join('\n'));

// 사라지는 URL 이 있으면 종료 코드 1 로 알린다. 워크플로가 실패로 표시한다.
const finalDiff = needsDeploy ? await sitemapDiff() : null;
if (finalDiff?.ok && finalDiff.missing.length) process.exit(1);
