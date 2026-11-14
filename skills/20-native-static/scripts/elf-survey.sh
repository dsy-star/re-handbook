#!/usr/bin/env bash
# elf-survey.sh — ELF/.so 静态勘察：架构、依赖、JNI 导出、可疑导入与字符串。
# 用法: elf-survey.sh <file.so> [--jni]
set -u
F="${1:-}"; JNI=0
[ "${2:-}" = "--jni" ] && JNI=1
if [ -z "$F" ] || [ ! -f "$F" ]; then echo "usage: elf-survey.sh <file.so> [--jni]" >&2; exit 2; fi

echo "== 文件 =="
file "$F" 2>/dev/null || echo "(无 file 命令)"
[ "$JNI" -eq 1 ] || { echo; echo "== 依赖 =="; (readelf -d "$F" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/  \1/p') || echo "(无 readelf)"; }

echo; echo "== JNI 导出（静态注册） =="
if command -v nm >/dev/null 2>&1; then
  nm -D --defined-only "$F" 2>/dev/null | awk '{print $3}' | grep '^Java_' | head -40
  nm -D --defined-only "$F" 2>/dev/null | awk '{print $3}' | grep -E 'JNI_OnLoad|JNI_OnUnload' || true
  EXP=$(nm -D --defined-only "$F" 2>/dev/null | wc -l | tr -d ' ')
  echo "  (动态导出总数: ${EXP:-0})"
else
  echo "(无 nm；装 binutils 或改用 rizin -qs 'is~Java_')"
fi

echo; echo "== 可疑导入 =="
if command -v readelf >/dev/null 2>&1; then
  readelf -Ws "$F" 2>/dev/null | awk '$7=="UND"{print $8}' | grep -Ei 'SSL_|EVP_|AES_|SHA|MD5|socket|connect|dlopen|dlsym|__android_log_print|ptrace|fork' | sort -u | head -30
else
  echo "(无 readelf)"
fi

echo; echo "== 字符串线索 =="
if command -v strings >/dev/null 2>&1; then
  strings -a "$F" 2>/dev/null | grep -Ei 'https?://|RegisterNatives|encrypt|decrypt|sign|hmac|aes|token|appkey|secret|/proc/self/maps|frida|su\b' | sort -u | head -40
else
  echo "(无 strings)"
fi

cat <<'EOF'

判读：
  有 Java_* 导出        → 静态注册，函数名即 类名+方法名
  只有 JNI_OnLoad       → 大概率 RegisterNatives 动态注册（运行时才可确认注册了哪些方法）
  少数超大函数(>10KB)   → 混淆（控制流平坦化），别硬读伪代码
  无 crypto 导入但有 SBox 常量 → 算法自实现/魔改，按常量定位
边界：静态只能证明"存在调用点/字符串/导入"，不能证明运行时行为。
EOF
