// push-api.mjs — 走 GitHub REST API 上传整个仓库（不依赖 git 传输层）
//
// 为什么存在：本机 github.com 的 git smart-HTTP 端点曾整段超时（20s / 0 字节），
// 而 api.github.com 可达。用 Blobs → Tree → Commit → Ref 四步把工作区内容推上去。
//
// 用法：
//   GITHUB_TOKEN=xxx node tools/push-api.mjs
//   GITHUB_TOKEN=xxx GITHUB_OWNER=someone REPO_NAME=re-handbook node tools/push-api.mjs
//   PRIVATE=true ...            # 建私有库
//
// token 权限：classic 勾 repo；fine-grained 需 Administration(RW) + Contents(RW)。
// token 只从环境变量读，不写文件、不写 .git/config。

import { execFileSync } from 'node:child_process';
import { readFileSync, statSync } from 'node:fs';

const API = 'https://api.github.com';
const TOKEN = process.env.GITHUB_TOKEN;
const NAME = process.env.REPO_NAME || 're-handbook';
const BRANCH = process.env.BRANCH || 'main';
const PRIVATE = String(process.env.PRIVATE || 'false') === 'true';
const SKIP_FILES = /^(node_modules\/)/;

if (!TOKEN) {
  console.error('缺少环境变量 GITHUB_TOKEN');
  process.exit(2);
}

// 传输层用 curl：Node 26 的 fetch 走 HTTP/2，经本地代理时被判 INTERNAL_ERROR 断连；
// curl 已验证可稳定访问 api.github.com。大文件偶发 schannel 断连，故带重试。
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

function req(method, path, body) {
  const args = [
    '-sS', '--http1.1', '-m', '180', '-X', method, API + path,
    '-H', 'Authorization: Bearer ' + TOKEN,
    '-H', 'Accept: application/vnd.github+json',
    '-H', 'X-GitHub-Api-Version: 2022-11-28',
    '-H', 'User-Agent: re-handbook-push',
    '-H', 'Expect:',
    '-w', '\n%{http_code}',
  ];
  let input;
  if (body !== undefined) {
    args.push('-H', 'Content-Type: application/json', '--data-binary', '@-');
    input = JSON.stringify(body);
  }
  let last = { status: 0, json: null, text: 'no attempt' };
  for (let attempt = 1; attempt <= 4; attempt++) {
    let out = '';
    let err = '';
    try {
      out = execFileSync('curl', args, { input, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, stdio: ['pipe', 'pipe', 'pipe'] });
    } catch (e) {
      err = String((e.stderr || e.message || e)).slice(0, 200);
    }
    const i = out.lastIndexOf('\n');
    const status = i >= 0 ? Number(out.slice(i + 1).trim()) || 0 : 0;
    const text = i >= 0 ? out.slice(0, i) : out;
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch { /* 非 JSON */ }
    last = { status, json, text: text || err };
    if (status >= 200 && status < 300) return last;
    if (status !== 0 && status < 500) return last;   // 4xx 不重试
    if (attempt < 4) { console.log(`    · 第 ${attempt} 次失败（HTTP ${status}），重试`); sleep(1500 * attempt); }
  }
  return last;
}

const say = (...a) => console.log(...a);

// 1) 身份
const me = req('GET', '/user');
if (me.status !== 200 || !me.json?.login) {
  console.error(`鉴权失败（HTTP ${me.status}）：${me.json?.message || me.text.slice(0, 200)}`);
  process.exit(3);
}
const OWNER = process.env.GITHUB_OWNER || me.json.login;
say(`账号：${OWNER}    目标：${OWNER}/${NAME}（private=${PRIVATE}）`);

// 2) 建库（已存在则复用）
const repoPath = `/repos/${OWNER}/${NAME}`;
let repo = req('GET', repoPath);
if (repo.status === 404) {
  const created = req('POST', '/user/repos', {
    name: NAME,
    description: process.env.REPO_DESC || '逆向工程与模块开发工具书：方法论、证据规范、分类工具与部署方案',
    private: PRIVATE,
    has_issues: true,
    has_wiki: false,
    auto_init: false,
  });
  if (created.status >= 300) {
    console.error(`建库失败（HTTP ${created.status}）：${created.json?.message || created.text.slice(0, 200)}`);
    const detail = created.json?.errors?.[0]?.message;
    if (detail) console.error(`  ${detail}`);
    process.exit(4);
  }
  repo = created;
  say(`已创建：${repo.json.html_url}`);
} else if (repo.status === 200) {
  say(`仓库已存在，继续复用：${repo.json.html_url}`);
} else {
  console.error(`查询仓库失败（HTTP ${repo.status}）：${repo.json?.message || me.text?.slice(0, 200)}`);
  process.exit(4);
}

// 2.5) 空仓库无法直接创建 blob（409 "Git Repository is empty"），先用 Contents API 落一个初始提交
let headRef = req('GET', `${repoPath}/git/ref/heads/${BRANCH}`);
if (headRef.status !== 200) {
  say(`空仓库检测：GET ref → HTTP ${headRef.status}`);
  const seed = req('PUT', `${repoPath}/contents/README.md`, {
    message: 'chore: 初始化仓库',
    content: Buffer.from('re-handbook\n').toString('base64'),
    branch: BRANCH,
  });
  if (seed.status >= 300) {
    console.error(`建立初始提交失败（HTTP ${seed.status}）：${seed.json?.message || seed.text.slice(0, 200)}`);
    process.exit(4);
  }
  say('空仓库：已建立初始提交，随后整体覆盖');
  headRef = req('GET', `${repoPath}/git/ref/heads/${BRANCH}`);
}

// 3) 逐文件上传 blob
const files = execFileSync('git', ['ls-files'], { encoding: 'utf8' })
  .split('\n')
  .map((s) => s.trim())
  .filter((f) => f && !SKIP_FILES.test(f));

const tree = [];
let uploaded = 0;
for (const f of files) {
  let buf;
  try { buf = readFileSync(f); } catch { continue; }
  const mode = f.includes('/scripts/') || f.endsWith('.sh') || f.endsWith('.mjs') ? '100755' : '100644';
  const blob = req('POST', `${repoPath}/git/blobs`, {
    content: buf.toString('base64'),
    encoding: 'base64',
  });
  if (blob.status >= 300 || !blob.json?.sha) {
    console.error(`✗ 上传失败：${f}（HTTP ${blob.status}）${blob.json?.message || ''}`);
    process.exit(5);
  }
  tree.push({ path: f, mode, type: 'blob', sha: blob.json.sha });
  uploaded += 1;
  process.stdout.write(`  ${f} → ${blob.json.sha.slice(0, 8)}\n`);
}
say(`已上传 ${uploaded} 个文件`);

// 4) tree
const treeRes = req('POST', `${repoPath}/git/trees`, { tree });
if (treeRes.status >= 300 || !treeRes.json?.sha) {
  console.error(`建 tree 失败（HTTP ${treeRes.status}）：${treeRes.json?.message || ''}`);
  process.exit(6);
}
say(`tree: ${treeRes.json.sha}`);

// 5) commit（分支已存在则挂在其后）
const parents = [];
const refRes = req('GET', `${repoPath}/git/ref/heads/${BRANCH}`);
if (refRes.status === 200 && refRes.json?.object?.sha) {
  parents.push(refRes.json.object.sha);
  say(`分支已存在，父提交：${refRes.json.object.sha.slice(0, 8)}`);
}
const commitRes = req('POST', `${repoPath}/git/commits`, {
  message: process.env.COMMIT_MSG || `chore: 上传 re-handbook（${uploaded} 个文件）`,
  tree: treeRes.json.sha,
  parents,
});
if (commitRes.status >= 300 || !commitRes.json?.sha) {
  console.error(`建 commit 失败（HTTP ${commitRes.status}）：${commitRes.json?.message || ''}`);
  process.exit(7);
}
say(`commit: ${commitRes.json.sha}`);

// 6) 建 / 更新 ref
const refOut = parents.length === 0
  ? req('POST', `${repoPath}/git/refs`, { ref: `refs/heads/${BRANCH}`, sha: commitRes.json.sha })
  : req('PATCH', `${repoPath}/git/refs/heads/${BRANCH}`, { sha: commitRes.json.sha, force: false });

if (refOut.status >= 300) {
  console.error(`更新 ref 失败（HTTP ${refOut.status}）：${refOut.json?.message || ''}`);
  process.exit(8);
}
say(`✓ 推送完成：https://github.com/${OWNER}/${NAME}/tree/${BRANCH}`);
say(`  提交页面：https://github.com/${OWNER}/${NAME}/commit/${commitRes.json.sha}`);
