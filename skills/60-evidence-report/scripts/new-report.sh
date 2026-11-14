#!/usr/bin/env bash
# new-report.sh — 生成报告骨架：范围/方法/结论表/限制/未知/附录。
# 用法: new-report.sh <out.md> <目标名> [范围描述]
set -u
OUT="${1:-}"; NAME="${2:-}"; SCOPE="${3:-}"
[ -n "$OUT" ] && [ -n "$NAME" ] || { echo "usage: new-report.sh <out.md> <目标名> [范围]" >&2; exit 2; }
TPL="$(cd "$(dirname "$0")/.." && pwd)/templates/report.md"
[ -f "$TPL" ] || { echo "缺少模板: $TPL" >&2; exit 2; }
mkdir -p "$(dirname "$OUT")"
sed -e "s|{{TARGET}}|$NAME|g" -e "s|{{SCOPE}}|${SCOPE:-（待补充：分析范围）}|g" \
    -e "s|{{DATE}}|$(date +%Y-%m-%d)|g" "$TPL" > "$OUT"
echo "已生成: $OUT"
echo "下一步：每条结论填 evidence 与 type（观测/推断/未知），空着不算完成。"
