#!/usr/bin/env bash
# jadx-run.sh — jadx 反编译封装：默认 --no-res（快），可选资源/去混淆/坏代码显示。
# 用法: jadx-run.sh <apk|jar|aar> [-o OUT] [--res] [--deobf] [--bad] [--engine jadx|fernflower|both]
set -u
if [ $# -lt 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,3p' "$0"; exit 2; fi
IN="$1"; shift
OUT=""; RES=0; DEOBF=0; BAD=0; ENGINE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="${2:-}"; shift 2 ;;
    --res) RES=1; shift ;;
    --deobf) DEOBF=1; shift ;;
    --bad) BAD=1; shift ;;
    --engine) ENGINE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -f "$IN" ] || { echo "not a file: $IN" >&2; exit 2; }
command -v jadx >/dev/null 2>&1 || { echo "需要 jadx（DEPLOY §4）。大 APK 记得 export JAVA_OPTS=\"-Xmx4096m\"" >&2; exit 2; }

BASE=$(basename "$IN"); NAME="${BASE%.*}"
[ -n "$OUT" ] || OUT="work/$NAME/src"
mkdir -p "$OUT"

ARGS=(-d "$OUT" -j "$(nproc 2>/dev/null || echo 4)")
[ "$RES" -eq 0 ] && ARGS+=(--no-res)
[ "$DEOBF" -eq 1 ] && ARGS+=(--deobf)
[ "$BAD" -eq 1 ] && ARGS+=(--show-bad-code)
[ -n "$ENGINE" ] && ARGS+=(--engine "$ENGINE")

echo "# jadx ${ARGS[*]} $IN" >&2
if ! jadx "${ARGS[@]}" "$IN" 2>&1 | tail -20; then
  echo "jadx 失败：先看是不是 OOM（export JAVA_OPTS=\"-Xmx4096m\"）" >&2; exit 1
fi

N=$(find "$OUT/sources" -name '*.java' 2>/dev/null | wc -l | tr -d ' ')
echo "输出: $OUT"
echo "java 文件: ${N:-0}"
if [ "$DEOBF" -eq 1 ]; then
  cat >&2 <<'WARN'

注意：本次用了 --deobf。若下一步要 Frida / JNI / unidbg 等运行时动作，
      必须用**原始名**重新反编译（不带 --deobf），否则 ClassNotFound。
WARN
fi
