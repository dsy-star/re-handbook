#!/usr/bin/env bash
# preflight.sh — 构建前置检查：JDK17 / Android SDK / Gradle wrapper。可选 --device 查设备。
set -u
DEVICE=0; [ "${1:-}" = "--device" ] && DEVICE=1
FAIL=0

echo "== JDK 17 =="
JDK17=""
for c in "${JDK_HOME:-}" "${JAVA_HOME:-}"; do
  [ -n "$c" ] && [ -x "$c/bin/java" ] && { JDK17="$c"; break; }
done
if [ -z "$JDK17" ] && [ "$(uname -s)" = "Darwin" ] && [ -x /usr/libexec/java_home ]; then
  c=$(/usr/libexec/java_home -v 17 2>/dev/null) && [ -n "$c" ] && JDK17="$c"
fi
if [ -z "$JDK17" ]; then
  for c in /opt/homebrew/opt/openjdk@17 /usr/local/opt/openjdk@17 /opt/homebrew/opt/temurin@17 /usr/local/opt/temurin@17 /usr/lib/jvm/java-17-openjdk-amd64 /Library/Java/JavaVirtualMachines/*/Contents/Home; do
    [ -x "$c/bin/java" ] && { JDK17="$c"; break; }
  done
fi
if [ -z "$JDK17" ] && command -v java >/dev/null 2>&1; then
  V=$(java -version 2>&1 | head -1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p')
  [ "${V:-0}" = "17" ] && JDK17=$(dirname "$(dirname "$(command -v java)")")
fi
if [ -n "$JDK17" ]; then echo "  ✓ JDK17 = $JDK17"; else echo "  ✗ 未找到 JDK 17（设 JDK_HOME；Windows 必须手动设）"; FAIL=1; fi

echo "== Android SDK =="
SDK=""
for c in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do [ -n "$c" ] && [ -d "$c" ] && { SDK="$c"; break; }; done
if [ -z "$SDK" ] && [ -f local.properties ]; then SDK=$(sed -n 's/^sdk\.dir=//p' local.properties | tail -1); fi
if [ -z "$SDK" ]; then
  for c in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" "$HOME/Android/sdk"; do [ -d "$c" ] && { SDK="$c"; break; }; done
fi
if [ -n "$SDK" ] && [ -d "$SDK" ]; then
  echo "  ✓ SDK = $SDK"
  if [ ! -f local.properties ] || ! grep -q '^sdk\.dir=' local.properties 2>/dev/null; then
    echo "sdk.dir=$SDK" >> local.properties; echo "  · 已写入 local.properties（不要提交）"
  fi
else
  echo "  ✗ 未找到 SDK（设 ANDROID_HOME 或 local.properties）"; FAIL=1
fi

echo "== Gradle wrapper =="
if [ -x ./gradlew ]; then echo "  ✓ ./gradlew"
elif [ -f ./gradlew ]; then echo "  ✓ ./gradlew（需 chmod +x）"
elif [ -n "${GRADLEW:-}" ] && [ -x "$GRADLEW" ]; then echo "  ✓ GRADLEW=$GRADLEW"
elif command -v gradle >/dev/null 2>&1; then echo "  ! 只有全局 gradle（$(gradle --version 2>/dev/null | sed -n 's/^Gradle //p' | head -1)）；建议补 wrapper"
else echo "  ✗ 没有 wrapper 也没有 gradle"; FAIL=1; fi

if [ "$DEVICE" -eq 1 ]; then
  echo "== 设备 =="
  D=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1; exit}')
  [ -n "${D:-}" ] && echo "  ✓ $D" || { echo "  ✗ 无已授权设备"; FAIL=1; }
fi

[ -n "$JDK17" ] && echo "JDK17_HOME=$JDK17"
[ "$FAIL" -eq 0 ] && echo "结果：可以构建" || echo "结果：缺项，先补再构建"
exit "$FAIL"
