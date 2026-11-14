#!/usr/bin/env bash
# run-frida.sh — Frida 运行封装：先打设备信息，再按 attach/spawn 执行脚本。
# 用法: run-frida.sh -p <pkg|pid> -l <script.js>
#       run-frida.sh -f <pkg> -l <script.js>      # spawn
#       run-frida.sh --package <pkg> --script <script.js> [--spawn] [--stay]
set -u
PKG=""; PID=""; SCRIPT=""; SPAWN=0; STAY=1
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--pid) PID="${2:-}"; shift 2 ;;
    -f|--file) PKG="${2:-}"; SPAWN=1; shift 2 ;;
    --package) PKG="${2:-}"; shift 2 ;;
    -l|--script) SCRIPT="${2:-}"; shift 2 ;;
    --spawn) SPAWN=1; shift ;;
    --no-stay) STAY=0; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$SCRIPT" ] && [ -f "$SCRIPT" ] || { echo "需要 -l <存在的脚本>" >&2; exit 2; }
command -v frida >/dev/null 2>&1 || { echo "需要 frida-tools（DEPLOY §5.1）" >&2; exit 2; }
command -v adb >/dev/null 2>&1 && {
  echo "# device: $(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')" >&2
  echo "# frida: $(frida --version)  server: $(adb shell '/data/local/tmp/frida-server --version' 2>/dev/null | tr -d '\r')" >&2
}
echo "# script sha256: $( (sha256sum "$SCRIPT" 2>/dev/null || shasum -a 256 "$SCRIPT") | awk '{print $1}' | cut -c1-16)" >&2

ARGS=(-U)
if [ "$SPAWN" -eq 1 ] && [ -n "$PKG" ]; then ARGS+=(-f "$PKG")
elif [ -n "$PID" ]; then ARGS+=(-p "$PID")
elif [ -n "$PKG" ]; then ARGS+=(-n "$PKG")
else echo "需要 -p 或 -f/--package" >&2; exit 2; fi
ARGS+=(-l "$SCRIPT")
[ "$STAY" -eq 0 ] && ARGS+=(--eternalize 2>/dev/null || true)

echo "# frida ${ARGS[*]}（注意：现代 CLI 没有 --no-pause）" >&2
exec frida "${ARGS[@]}"
