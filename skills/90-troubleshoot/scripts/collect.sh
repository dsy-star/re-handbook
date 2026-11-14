#!/usr/bin/env bash
# collect.sh — 一条命令采现场。只读，不重启服务、不改模块状态。
# 用法: collect.sh [--out DIR] [--apk path.apk]
set -u
OUT=""; APK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --apk) APK="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done
[ -n "$OUT" ] || OUT="work/diag-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

{
  echo "== uname =="; uname -a 2>/dev/null
  echo "== node/java/rea =="; node --version 2>/dev/null; java -version 2>&1 | head -3; rea --version 2>/dev/null
  echo "== jadx/apktool/rizin =="; jadx --version 2>/dev/null; apktool --version 2>/dev/null; rizin -v 2>/dev/null | head -2
  echo "== frida =="; frida --version 2>/dev/null
  echo "== env =="; echo "JDK_HOME=${JDK_HOME:-}"; echo "ANDROID_HOME=${ANDROID_HOME:-}"; echo "ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-}"
} > "$OUT/env.txt" 2>&1

{ echo "== adb devices =="; adb devices -l 2>&1
  echo "== 设备信息 =="; D=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
  if [ -n "${D:-}" ]; then
    echo "serial=$D"
    adb -s "$D" shell getprop ro.product.cpu.abi 2>/dev/null
    adb -s "$D" shell getprop ro.build.version.release 2>/dev/null
    adb -s "$D" shell "/data/local/tmp/frida-server --version" 2>/dev/null
  fi
} > "$OUT/device.txt" 2>&1

{ adb logcat -d 2>/dev/null | tail -2000; } > "$OUT/logcat.txt" 2>&1

{ adb shell "su -c '/data/adb/lspd/cli status' " 2>/dev/null || adb shell "/data/adb/lspd/cli status" 2>/dev/null; } > "$OUT/vector.txt" 2>&1

if [ -n "$APK" ] && [ -f "$APK" ]; then
  { echo "apk=$APK"; (sha256sum "$APK" 2>/dev/null || shasum -a 256 "$APK"); unzip -Z1 "$APK" 2>/dev/null | head -50; } > "$OUT/apk.txt" 2>&1
fi

cat > "$OUT/README.txt" <<EOF
采集时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)
文件：
  env.txt      版本快照（先看这里的 MISSING/版本不匹配）
  device.txt   adb 与设备/服务端版本
  logcat.txt   最近 2000 行
  vector.txt   模块管理器状态（若有）
  apk.txt      样本指纹与条目（若传了 --apk）
判读：BOOK 8.1–8.2；两种超时要分清 host deadline 与 provider 超时。
EOF
echo "已采集到: $OUT"
ls -1 "$OUT"
