#!/usr/bin/env bash
# vector-cli.sh — Vector/LSPosed CLI 封装，带版本门禁：Version Code >= 3043 才允许改状态。
# 用法: vector-cli.sh status [--json]
#       vector-cli.sh modules
#       vector-cli.sh enable|disable <module.pkg>
#       vector-cli.sh scope-add <module.pkg> <target.pkg>[/user]
#       vector-cli.sh scope-set <module.pkg> <target.pkg>[/user] ...
#       vector-cli.sh scope-rm  <module.pkg> <target.pkg>[/user]
#       vector-cli.sh log [lines]
set -u
CLI="/data/adb/lspd/cli"
MIN_VC=3043
have_adb() { command -v adb >/dev/null 2>&1; }
run_cli() {
  if adb shell "su -c 'test -x $CLI'" >/dev/null 2>&1; then
    adb shell "su -c '$CLI $*'"
  else
    adb shell "$CLI $*"
  fi
}
if ! have_adb; then echo "需要 adb" >&2; exit 2; fi

CMD="${1:-status}"; shift || true
case "$CMD" in
  status) run_cli status "$@" ;;
  modules) run_cli modules ls ;;
  log) N="${1:-200}"; run_cli log cat | tail -n "$N" ;;
  enable|disable)
    PKG="${1:-}"; [ -n "$PKG" ] || { echo "用法: $CMD <module.pkg>" >&2; exit 2; }
    VC=$(run_cli status --json 2>/dev/null | sed -n 's/.*"versionCode"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -1)
    [ -z "$VC" ] && VC=$(run_cli status 2>/dev/null | sed -n 's/.*[Vv]ersion [Cc]ode[^0-9]*\([0-9]\+\).*/\1/p' | head -1)
    if [ -z "${VC:-}" ]; then
      echo "无法解析 Vector 版本码：不自动改模块状态。" >&2
      echo "请手动在管理器里启用 $PKG 并配置作用域。" >&2; exit 3
    fi
    if [ "$VC" -lt "$MIN_VC" ]; then
      echo "Vector Version Code=$VC < $MIN_VC：按纪律不自动修改状态。" >&2
      echo "APK 已安装即可；请在管理器里手动启用 $PKG 并勾选作用域，然后重启目标应用。" >&2; exit 3
    fi
    if [ "$CMD" = "enable" ]; then run_cli modules enable "$PKG"; else run_cli modules disable "$PKG"; fi ;;
  scope-add) MOD="${1:-}"; TGT="${2:-}"; [ -n "$MOD" ] && [ -n "$TGT" ] || { echo "用法: scope-add <module.pkg> <target.pkg>[/user]" >&2; exit 2; }
    VC=$(run_cli status --json 2>/dev/null | sed -n 's/.*"versionCode"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -1)
    if [ -z "${VC:-}" ] || [ "$VC" -lt "$MIN_VC" ]; then echo "Version Code=${VC:-未知} < $MIN_VC：请手动配 scope。" >&2; exit 3; fi
    run_cli scope add "$MOD" "$TGT" ;;
  scope-set) MOD="${1:-}"; shift || true; [ -n "$MOD" ] && [ $# -gt 0 ] || { echo "用法: scope-set <module.pkg> <target...>" >&2; exit 2; }
    VC=$(run_cli status --json 2>/dev/null | sed -n 's/.*"versionCode"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -1)
    if [ -z "${VC:-}" ] || [ "$VC" -lt "$MIN_VC" ]; then echo "Version Code=${VC:-未知} < $MIN_VC：请手动配 scope。" >&2; exit 3; fi
    run_cli scope set "$MOD" "$@" ;;
  scope-rm) MOD="${1:-}"; TGT="${2:-}"; [ -n "$MOD" ] && [ -n "$TGT" ] || { echo "用法: scope-rm <module.pkg> <target.pkg>" >&2; exit 2; }
    run_cli scope rm "$MOD" "$TGT" ;;
  -h|--help) sed -n '2,10p' "$0" ;;
  *) echo "unknown cmd: $CMD" >&2; sed -n '2,10p' "$0"; exit 2 ;;
esac
