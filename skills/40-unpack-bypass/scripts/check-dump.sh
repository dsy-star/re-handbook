#!/usr/bin/env bash
# check-dump.sh — 校验脱壳产物：dex magic、可解析性、方法体抽取残留。
# 用法: check-dump.sh <dir-with-dex>
set -u
D="${1:-}"
[ -d "${D:-}" ] || { echo "usage: check-dump.sh <dir-with-dex>" >&2; exit 2; }
N=0; BAD=0
for f in "$D"/*.dex; do
  [ -f "$f" ] || continue
  N=$((N+1))
  MAGIC=$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')
  case "$MAGIC" in
    6465780a30333500|6465780a30333600|6465780a30333700|6465780a30333800|6465780a30333900)
      echo "  ✓ $(basename "$f")  $(wc -c < "$f" | tr -d ' ') bytes" ;;
    *) echo "  ✗ $(basename "$f") magic=$MAGIC （不是合法 dex）"; BAD=$((BAD+1)) ;;
  esac
done
[ "$N" -eq 0 ] && { echo "目录里没有 .dex"; exit 1; }
echo "共 $N 个 dex，异常 $BAD 个"

if command -v jadx >/dev/null 2>&1; then
  echo "== 解析测试（取第一个 dex） =="
  FIRST=$(ls "$D"/*.dex 2>/dev/null | head -1)
  OUT="work/.dump-check-$$"
  if jadx --no-res -d "$OUT" "$FIRST" >/dev/null 2>&1; then echo "  ✓ 可被 jadx 解析"
  else echo "  ✗ 解析失败：header/checksum 可能被壳改坏，需修复后再分析"; fi
  rm -rf "$OUT"
else
  echo "(无 jadx：跳过解析测试)"
fi
cat <<'EOF'

边界：通过本检查只说明"dex 结构可读"，不说明"方法体完整"。
      方法抽取型壳脱壳后常见 native/空方法体，需人工抽样确认。
EOF
