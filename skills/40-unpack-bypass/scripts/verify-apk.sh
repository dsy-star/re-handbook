#!/usr/bin/env bash
# verify-apk.sh — 包自检：模块三件套 / 桩泄漏 / 对齐 / 签名。
# 用法: verify-apk.sh <apk> [--module]
set -u
APK="${1:-}"; MODULE=0
[ "${2:-}" = "--module" ] && MODULE=1
[ -f "${APK:-}" ] || { echo "usage: verify-apk.sh <apk> [--module]" >&2; exit 2; }
if ! command -v unzip >/dev/null 2>&1 && ! command -v jar >/dev/null 2>&1; then
  echo "需要 unzip 或 jar" >&2; exit 2
fi
FAIL=0
ABS=$(cd "$(dirname "$APK")" && pwd)/$(basename "$APK")

list_entries() {
  if command -v unzip >/dev/null 2>&1; then unzip -Z1 "$1" 2>/dev/null
  else jar tf "$1" 2>/dev/null; fi
}
read_entry() {
  local apk="$1" entry="$2" tmp
  if command -v unzip >/dev/null 2>&1; then
    unzip -p "$apk" "$entry" 2>/dev/null; return 0
  fi
  tmp="$(dirname "$apk")/.rd-$$"; rm -rf "$tmp"; mkdir -p "$tmp"
  ( cd "$tmp" && jar xf "$apk" "$entry" >/dev/null 2>&1 )
  [ -f "$tmp/$entry" ] && cat "$tmp/$entry"
  rm -rf "$tmp"
}
ZLIST=$(list_entries "$ABS" | tr -d '\r')

if [ "$MODULE" -eq 1 ]; then
  echo "== 模块入口 =="
  MP=$(read_entry "$ABS" META-INF/xposed/module.prop)
  if [ -n "${MP:-}" ]; then
    printf '%s\n' "$MP" | tr -d '\r' | sed 's/^/  /'
    for k in minApiVersion targetApiVersion staticScope; do
      printf '%s\n' "$MP" | tr -d '\r' | grep -q "^$k=" || { echo "  ✗ 缺少 $k"; FAIL=1; }
    done
    printf '%s\n' "$MP" | tr -d '\r' | grep -q '^minApiVersion=101' || { echo "  ✗ minApiVersion 应为 101"; FAIL=1; }
    printf '%s\n' "$MP" | tr -d '\r' | grep -q '^targetApiVersion=101' || { echo "  ✗ targetApiVersion 应为 101（100 可能不按 modern 加载）"; FAIL=1; }
  else
    echo "  ✗ META-INF/xposed/module.prop 不存在"; FAIL=1
  fi
  JI=$(read_entry "$ABS" META-INF/xposed/java_init.list)
  if [ -n "${JI:-}" ]; then echo "  java_init.list: $(printf '%s' "$JI" | tr -d '\r')"
  else echo "  ✗ META-INF/xposed/java_init.list 不存在"; FAIL=1; fi
  if printf '%s\n' "$ZLIST" | grep -q 'io/github/libxposed'; then
    echo "  ✗ 桩被打进 APK（应为 compileOnly）"; FAIL=1
  else echo "  ✓ 未打包 libxposed 桩"; fi
  printf '%s\n' "$ZLIST" | grep -q 'assets/xposed_init' && echo "  · 存在 assets/xposed_init（legacy 回退，可接受）"
fi

echo "== dex =="
printf '%s\n' "$ZLIST" | grep -E '(^|/)classes[0-9]*\.dex$' | sed 's/^/  /'

echo "== 对齐 / 签名 =="
if command -v apksigner >/dev/null 2>&1; then
  apksigner verify --print-certs "$ABS" 2>&1 | head -6 | sed 's/^/  /' || { echo "  ✗ apksigner verify 失败"; FAIL=1; }
else echo "  (无 apksigner：无法确认签名有效)"; fi
if command -v zipalign >/dev/null 2>&1; then
  zipalign -c -v 4 "$ABS" >/dev/null 2>&1 && echo "  ✓ 4 字节对齐" || { echo "  ✗ 未对齐：先 zipalign 再签名"; FAIL=1; }
else echo "  (无 zipalign)"; fi

[ "$FAIL" -eq 0 ] && echo "结果：通过" || echo "结果：有问题（见上）"
exit "$FAIL"
