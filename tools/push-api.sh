#!/usr/bin/env bash
# push-api.sh — 走 GitHub REST API 上传整个仓库（当 github.com:443 的 git 协议不可用时使用）
#
# 背景：本机 github.com 的 smart-HTTP 端点连接超时，但 api.github.com 可达，
#       因此用 Blobs → Tree → Commit → Ref 四步把工作区内容推上去，不依赖 git 传输层。
#
# 用法：
#   GITHUB_TOKEN=ghp_xxx bash tools/push-api.sh                 # owner 自动取 token 所属账号
#   GITHUB_TOKEN=ghp_xxx GITHUB_OWNER=someone bash tools/push-api.sh
#   PRIVATE=true GITHUB_TOKEN=... bash tools/push-api.sh        # 建私有库
#
# 需要的 token 权限：
#   - classic PAT：勾 repo（建库 + 写内容）
#   - fine-grained PAT：Administration=Read/Write（建库）、Contents=Read/Write（写内容）
#
# 安全：token 只作为环境变量传入，不写入 .git/config，不落到任何文件。
set -euo pipefail

: "${GITHUB_TOKEN:?请设置环境变量 GITHUB_TOKEN（不要把 token 写进脚本或提交）}"
NAME="${REPO_NAME:-re-handbook}"
DESC="${REPO_DESC:-逆向工程与模块开发工具书：方法论、证据规范、分类工具与部署方案}"
PRIVATE="${PRIVATE:-false}"
BRANCH="${BRANCH:-main}"
MSG="${COMMIT_MSG:-chore: 通过 REST API 上传 re-handbook v1.0}"
API="https://api.github.com"

command -v jq >/dev/null 2>&1 || { echo "需要 jq" >&2; exit 2; }
command -v base64 >/dev/null 2>&1 || { echo "需要 base64" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "需要 git（用于 git ls-files 取文件清单）" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "请在仓库根目录运行" >&2; exit 2; }

api() { # api METHOD PATH [JSON]
  local m="$1" p="$2" d="${3:-}"
  if [ -n "$d" ]; then
    curl -sS -m 60 -X "$m" "$API$p" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      -d "$d"
  else
    curl -sS -m 60 -X "$m" "$API$p" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28"
  fi
}

say() { printf '%s\n' "$*"; }

# 0) 校验 token / 取 owner
ME=$(api GET /user)
if ! printf '%s' "$ME" | jq -e '.login' >/dev/null 2>&1; then
  say "鉴权失败，API 返回：" ; printf '%s\n' "$ME" | jq -c '{message, documentation_url}' 2>/dev/null || printf '%s\n' "$ME"
  exit 3
fi
GITHUB_OWNER="${GITHUB_OWNER:-$(printf '%s' "$ME" | jq -r .login)}"
say "账号：$GITHUB_OWNER   目标仓库：$NAME（private=$PRIVATE）"

# 1) 建库（已存在则跳过）
CREATED=$(api POST /user/repos "$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRIVATE" '{name:$n,description:$d,private:$p,has_issues:true,has_wiki:false,auto_init:false}')")
if printf '%s' "$CREATED" | jq -e '.full_name' >/dev/null 2>&1; then
  say "已创建：$(printf '%s' "$CREATED" | jq -r .html_url)"
else
  ERR=$(printf '%s' "$CREATED" | jq -r '.errors[0].message // .message // "unknown"' 2>/dev/null || echo unknown)
  if [ "$ERR" = "name already exists on this account" ] || [ "$ERR" = "Repository creation failed." ]; then
    say "仓库已存在，继续复用：$GITHUB_OWNER/$NAME"
  else
    say "建库失败：$ERR"; printf '%s\n' "$CREATED" | jq . 2>/dev/null | head -20; exit 4
  fi
fi

# 2) 每个文件 → blob（保留路径与可执行位）
TREE='[]'
COUNT=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  B64=$(base64 "$f" | tr -d '\n')
  MODE=100644
  case "$f" in */scripts/*.sh|*.sh) MODE=100755 ;; esac
  SHA=$(jq -nc --arg c "$B64" '{content:$c,encoding:"base64"}' \
        | curl -sS -m 120 -X POST "$API/repos/$GITHUB_OWNER/$NAME/git/blobs" \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            -H "Content-Type: application/json" --data-binary @- \
        | jq -r '.sha // empty')
  if [ -z "$SHA" ]; then say "✗ 上传失败：$f"; exit 5; fi
  TREE=$(jq --arg p "$f" --arg s "$SHA" --arg m "$MODE" '. + [{path:$p,mode:$m,type:"blob",sha:$s}]' <<<"$TREE")
  COUNT=$((COUNT+1))
  printf '  %s → %s\n' "$f" "${SHA:0:8}"
done < <(git ls-files)
say "已上传 $COUNT 个文件"

# 3) tree
TREE_SHA=$(jq -nc --argjson t "$TREE" '{tree:$t}' \
  | curl -sS -m 60 -X POST "$API/repos/$GITHUB_OWNER/$NAME/git/trees" \
      -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" --data-binary @- | jq -r '.sha // empty')
[ -n "$TREE_SHA" ] || { say "建 tree 失败"; exit 6; }
say "tree: $TREE_SHA"

# 4) commit（若分支已存在则接在它后面）
PARENTS='[]'
EXIST=$(api GET "/repos/$GITHUB_OWNER/$NAME/git/ref/heads/$BRANCH")
if printf '%s' "$EXIST" | jq -e '.object.sha' >/dev/null 2>&1; then
  PARENT=$(printf '%s' "$EXIST" | jq -r .object.sha)
  PARENTS=$(jq -nc --arg p "$PARENT" '[$p]')
  say "分支已存在，父提交：${PARENT:0:8}"
fi
COMMIT_SHA=$(jq -nc --arg m "$MSG" --arg t "$TREE_SHA" --argjson p "$PARENTS" '{message:$m,tree:$t,parents:$p}' \
  | curl -sS -m 60 -X POST "$API/repos/$GITHUB_OWNER/$NAME/git/commits" \
      -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" --data-binary @- | jq -r '.sha // empty')
[ -n "$COMMIT_SHA" ] || { say "建 commit 失败"; exit 7; }
say "commit: $COMMIT_SHA"

# 5) 建/更新 ref
if [ "$PARENTS" = "[]" ]; then
  RES=$(api POST "/repos/$GITHUB_OWNER/$NAME/git/refs" "$(jq -nc --arg r "refs/heads/$BRANCH" --arg s "$COMMIT_SHA" '{ref:$r,sha:$s}')")
else
  RES=$(api PATCH "/repos/$GITHUB_OWNER/$NAME/git/refs/heads/$BRANCH" "$(jq -nc --arg s "$COMMIT_SHA" '{sha:$s,force:false}')")
fi
if printf '%s' "$RES" | jq -e '.ref' >/dev/null 2>&1; then
  say "✓ 推送完成：https://github.com/$GITHUB_OWNER/$NAME"
else
  say "更新 ref 失败："; printf '%s\n' "$RES" | jq -c '{message}' 2>/dev/null; exit 8
fi
