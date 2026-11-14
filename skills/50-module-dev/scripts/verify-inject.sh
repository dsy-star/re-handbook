#!/usr/bin/env bash
# verify-inject.sh — 注入验证：清日志→冷启→抓三行关键日志。
# 用法: verify-inject.sh <target.pkg> [--tag VectorToastModule] [--wait 4]
set -u
TGT="${1:-}"; TAG="VectorToastModule"; WAIT=4
[ -n "$TGT" ] || { echo "usage: verify-inject.sh <target.pkg>" >&2; exit 2; }
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --wait) WAIT="${2:-4}"; shift 2 ;;
    *) shift ;;
  esac
done
command -v adb >/dev/null 2>&1 || { echo "需要 adb" >&2; exit 2; }

adb logcat -c 2>/dev/null
adb shell am force-stop "$TGT"
adb shell monkey -p "$TGT" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "$WAIT"
LOG=$(adb logcat -d 2>/dev/null | grep -E "$TAG|VectorModuleManager|VectorLifecycle|Failed to instantiate|Class does not extend" | tail -40)
printf '%s\n' "$LOG"

echo "---- 判定 ----"
P=0
grep -q "Loaded module" <<<"$LOG"            && echo "✓ 模块已加载"      || { echo "✗ 未见 Loaded module"; P=1; }
grep -q "hooked Application.attach" <<<"$LOG" && echo "✓ attach 已挂"     || { echo "✗ 未见 attach hook"; P=1; }
grep -q "injected package=$TGT" <<<"$LOG"     && echo "✓ 目标进程已注入"  || { echo "✗ 未见 injected package=$TGT"; P=1; }
if [ "$P" -ne 0 ]; then
  cat <<'HINT'

排查顺序：
  1) module.prop / java_init.list 是否真的在 APK 里（40-unpack-bypass/scripts/verify-apk.sh --module）
  2) java_init.list 里的入口类全限定名是否与代码一致
  3) 作用域是否包含目标包；改完 scope 必须 force-stop 再启动
  4) 仍失败看模块加载器日志：adb shell su -c "/data/adb/lspd/cli log cat"
HINT
fi
exit "$P"
