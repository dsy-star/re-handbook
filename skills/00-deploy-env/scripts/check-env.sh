#!/usr/bin/env bash
# check-env.sh — 分层环境自检。只读，不改系统。
# 用法: check-env.sh [--layer L0|L1|L2] [--tsv] [--help]
# 输出: TOOL<TAB>STATUS<TAB>DETAIL   STATUS ∈ OK|MISSING|OPTIONAL|WARN
# 退出: 0=所需层齐全  1=有 MISSING  2=参数错误
set -u

LAYER="L1"; TSV=0
while [ $# -gt 0 ]; do
  case "$1" in
    --layer) LAYER="${2:-}"; shift 2 ;;
    --layer=*) LAYER="${1#*=}"; shift ;;
    --tsv) TSV=1; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
case "$LAYER" in L0|L1|L2) ;; *) echo "bad --layer: $LAYER" >&2; exit 2 ;; esac

MISSING=0
row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; if [ "$2" = "MISSING" ]; then MISSING=$((MISSING+1)); fi; return 0; }
have() { command -v "$1" >/dev/null 2>&1; }

os_name() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo macos ;;
    Linux) echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows-msys ;;
    *) echo unknown ;;
  esac
}
OS=$(os_name)
[ "$TSV" -eq 1 ] || echo "# platform: $OS   layer: $LAYER" >&2

# ---------- 通用文件工具（L1 起需要） ----------
if [ "$LAYER" != "L0" ]; then
  have unzip && row unzip OK "$(unzip -v 2>/dev/null | head -1)" || row unzip MISSING "装 unzip（Windows 用 Git Bash 自带；apt install unzip）"
  if have sha256sum; then row sha256 OK "sha256sum"
  elif have shasum; then row sha256 OK "shasum -a 256"
  else row sha256 MISSING "装 coreutils（sha256sum）或 perl Digest::SHA"; fi
  have file && row file OK "$(file --version 2>/dev/null | head -1)" || row file OPTIONAL "file 缺失：判型只看扩展名会不可靠"
fi

# ---------- L1 静态链 ----------
if [ "$LAYER" != "L0" ]; then
  if have java; then
    JV=$(java -version 2>&1 | head -1)
    MAJ=$(printf '%s' "$JV" | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')
    if [ "${MAJ:-0}" = "17" ]; then row java OK "$JV"
    elif [ "${MAJ:-0}" -ge 18 ] 2>/dev/null; then row java WARN "$JV （非 17；jadx/apktool/Gradle 建议 17）"
    else row java MISSING "$JV （需要 17；设 JDK_HOME）"; fi
  else
    row java MISSING "未找到 java；装 JDK 17 并设 JDK_HOME"
  fi
  have jadx && row jadx OK "$(jadx --version 2>&1 | head -1)" || row jadx MISSING "装 jadx（DEPLOY §4）"
  have apktool && row apktool OK "$(apktool --version 2>&1 | head -1)" || row apktool OPTIONAL "apktool 缺失：资源回编不可用"
  have rizin && row rizin OK "$(rizin -v 2>&1 | head -1)" || row rizin OPTIONAL "rizin 缺失：native 勘察退化为 readelf/nm"
  have readelf && row readelf OK "binutils" || row readelf OPTIONAL "readelf 缺失：ELF 依赖/段信息不可读"
fi

# ---------- L2 动态 + 模块 ----------
if [ "$LAYER" = "L2" ]; then
  have adb && row adb OK "$(adb version 2>/dev/null | head -1)" || row adb MISSING "装 platform-tools（DEPLOY §5.1）"
  if have adb; then
    DEV=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
    if [ -n "${DEV:-}" ]; then
      row device OK "$DEV"
      ABI=$(adb -s "$DEV" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
      row device-abi OK "${ABI:-unknown}"
      SRV=$(adb -s "$DEV" shell "/data/local/tmp/frida-server --version" 2>/dev/null | tr -d '\r')
      if [ -n "${SRV:-}" ]; then row frida-server OK "$SRV"; else row frida-server WARN "设备上未运行/未安装 frida-server（DEPLOY §5.2）"; fi
    else
      row device MISSING "adb devices 无 device；开启 USB 调试并授权"
    fi
  fi
  if have frida; then
    FV=$(frida --version 2>/dev/null)
    row frida OK "$FV"
    if [ -n "${SRV:-}" ] && [ "${SRV%%%.*}" != "${FV%%%.*}" ]; then
      row frida-match WARN "本机 $FV vs 设备 $SRV：主版本需一致"
    fi
  else
    row frida MISSING "pipx install frida-tools"
  fi
  have objection && row objection OK "$(objection version 2>/dev/null | head -1)" || row objection OPTIONAL "objection 缺失：交互式探查不可用"
  have node && row node OK "$(node --version)" || row node MISSING "装 Node ^22.23.4 || ^24.22.1 || >=26.12.1"
  if have node; then
    NV=$(node --version | sed 's/^v//')
    if node -e 'const v=process.versions.node.split(".").map(Number);const ok=(v[0]===22&&(v[1]>23||(v[1]===23&&v[2]>=4)))||(v[0]===24&&(v[1]>22||(v[1]===22&&v[2]>=1)))||v[0]>=26;process.exit(ok?0:1)' 2>/dev/null; then
      row node-engines OK "$NV 满足 REA 要求"
    else
      row node-engines WARN "$NV 可能不满足 REA 的 engines 约束"
    fi
  fi
  have rea && row rea OK "$(rea --version 2>/dev/null)" || row rea OPTIONAL "未全局安装；可 npx -y rea-agents@6.9.0"
  have su >/dev/null 2>&1 || true
fi

if [ "$TSV" -eq 0 ]; then
  echo >&2
  if [ "$MISSING" -gt 0 ]; then
    echo "结论：$LAYER 有 $MISSING 项 MISSING —— 停在这一层，按 DEPLOY.md 装完再复跑。" >&2
  else
    echo "结论：$LAYER 无 MISSING。WARN/OPTIONAL 请写进交付物的「限制与未覆盖」。" >&2
  fi
fi
[ "$MISSING" -gt 0 ] && exit 1
exit 0
