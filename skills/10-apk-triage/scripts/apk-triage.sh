#!/usr/bin/env bash
# apk-triage.sh — APK 三分钟判型：dex 规模 / 引擎 / 加固特征。只读。
# 用法: apk-triage.sh <apk> [--json]
set -u
APK="${1:-}"; JSON=0
[ "${2:-}" = "--json" ] && JSON=1
if [ -z "$APK" ] || [ ! -f "$APK" ]; then echo "usage: apk-triage.sh <apk> [--json]" >&2; exit 2; fi
if ! command -v unzip >/dev/null 2>&1 && ! command -v jar >/dev/null 2>&1; then
  echo "需要 unzip 或 jar（JDK 自带）" >&2; exit 2
fi

list_entries() {
  if command -v unzip >/dev/null 2>&1; then unzip -Z1 "$1" 2>/dev/null
  else jar tf "$1" 2>/dev/null; fi
}

if command -v sha256sum >/dev/null 2>&1; then SHA=$(sha256sum "$APK" | awk '{print $1}')
else SHA=$(shasum -a 256 "$APK" | awk '{print $1}'); fi
SIZE=$(wc -c < "$APK" | tr -d ' ')
LIST=$(list_entries "$APK" | tr -d '\r')

DEXN=$(printf '%s\n' "$LIST" | grep -Ec '(^|/)classes[0-9]*\.dex$')
DEXSZ=0
if command -v unzip >/dev/null 2>&1; then
  DEXSZ=$(unzip -l "$APK" 2>/dev/null | awk '/classes[0-9]*\.dex$/{s+=$1} END{print s+0}')
fi

ENGINE="未知"; EBASIS=""
if printf '%s\n' "$LIST" | grep -q 'global-metadata.dat'; then ENGINE="Unity IL2CPP"; EBASIS="global-metadata.dat"
elif printf '%s\n' "$LIST" | grep -q 'libil2cpp\.so'; then ENGINE="Unity IL2CPP"; EBASIS="libil2cpp.so"
elif printf '%s\n' "$LIST" | grep -q 'libflutter\.so'; then ENGINE="Flutter"; EBASIS="libflutter.so"
elif printf '%s\n' "$LIST" | grep -q 'index\.android\.bundle'; then ENGINE="React Native"; EBASIS="index.android.bundle"
elif printf '%s\n' "$LIST" | grep -q 'app-service\.js'; then ENGINE="uni-app"; EBASIS="app-service.js"
elif printf '%s\n' "$LIST" | grep -q 'cordova\.js'; then ENGINE="Cordova"; EBASIS="cordova.js"
elif printf '%s\n' "$LIST" | grep -q 'libweexcore\.so'; then ENGINE="Weex"; EBASIS="libweexcore.so"
fi

PACK="未发现"; PBASIS=""
check_pack() {
  if printf '%s\n' "$LIST" | grep -qi -- "$1"; then PACK="$2"; PBASIS="$1"; return 0; fi
  return 1
}
check_pack 'libjiagu' '360 加固' || check_pack 'com/stub/StubApp' '360 加固' || check_pack 'assets/qihoo' '360 加固' \
|| check_pack 'libDexHelper' '梆梆' || check_pack 'libsecexe' '梆梆' || check_pack 'bangcle' '梆梆' \
|| check_pack 'libshellx' '腾讯乐固/御安全' || check_pack 'libtup\.so' '腾讯乐固/御安全' \
|| check_pack 'libnesec' '网易易盾' || check_pack 'ijiami' '爱加密' \
|| check_pack 'libnagain' 'DexProtector' || check_pack 'libbaiduprotect' '百度' \
|| check_pack 'libzuma' '阿里聚安全' || check_pack 'libkwscmm' '几维' \
|| check_pack 'libapssec' 'AppSealing' || check_pack 'libtosprotection' '通付盾' \
|| check_pack 'libnqshield' '网秦' || check_pack 'libkiroro' 'Kiro' || check_pack 'libx3g' '顶像'

if [ "$PACK" != "未发现" ]; then NEXT="BOOK 5.1 / 5.6：先判壳级别再决定要不要脱"
elif [ "$ENGINE" = "Unity IL2CPP" ]; then NEXT="BOOK 5.3：Il2CppDumper（按 metadata 版本选分支）"
elif [ "$ENGINE" = "Flutter" ]; then NEXT="BOOK 5.3：Flutter 抓包三法 + Dart AOT 边界"
elif [ "$ENGINE" = "未知" ]; then NEXT="BOOK 3.3：走 Java 层静态；必要时 3.4 看 so"
else NEXT="BOOK 3.3 / 4.1：H5/RN 层优先看 JS 与 WebView 调试"
fi

if [ "$JSON" -eq 1 ]; then
  cat <<JSON
{"apk":"$APK","sha256":"$SHA","bytes":$SIZE,"dex_count":${DEXN:-0},"dex_bytes":${DEXSZ:-0},"engine":"$ENGINE","engine_basis":"$EBASIS","packer":"$PACK","packer_basis":"$PBASIS","next":"$NEXT"}
JSON
  exit 0
fi

cat <<EOF
APK      : $APK
SHA-256  : $SHA
体积      : $SIZE bytes
dex      : ${DEXN:-0} 个（未压缩合计 ${DEXSZ:-0} bytes）
引擎特征  : $ENGINE  ${EBASIS:+($EBASIS)}
加固特征  : $PACK  ${PBASIS:+($PBASIS)}
下一步    : $NEXT

注意：加固判定基于文件名特征，只说明"存在该壳的文件"，需用 dex 里的 Application 类名交叉确认；
      未命中不等于无壳（可能是自定义壳或纯 native 应用）。
EOF
