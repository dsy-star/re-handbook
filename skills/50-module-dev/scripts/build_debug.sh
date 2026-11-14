#!/usr/bin/env bash
# build_debug.sh — 用 wrapper 构建 debug 包，显式指定 JDK17。不假设全局 gradle。
set -u
JDK="${JDK17_HOME:-${JDK_HOME:-${JAVA_HOME:-}}}"
if [ -z "$JDK" ] || [ ! -x "$JDK/bin/java" ]; then
  echo "未找到 JDK17：先跑 ./preflight.sh 并 export JDK17_HOME=<路径>" >&2; exit 2
fi
GRADLE_ARGS=(-Dorg.gradle.java.home="$JDK" :app:assembleDebug)
if [ -x ./gradlew ]; then
  echo "# ./gradlew ${GRADLE_ARGS[*]}" >&2
  ./gradlew "${GRADLE_ARGS[@]}"
elif [ -n "${GRADLEW:-}" ] && [ -x "$GRADLEW" ]; then
  echo "# $GRADLEW ${GRADLE_ARGS[*]}" >&2
  "$GRADLEW" "${GRADLE_ARGS[@]}"
elif command -v gradle >/dev/null 2>&1; then
  echo "# 警告：使用全局 gradle（版本可能与项目不匹配）" >&2
  gradle "${GRADLE_ARGS[@]}"
else
  echo "没有 gradlew / GRADLEW / gradle" >&2; exit 2
fi
APK=app/build/outputs/apk/debug/app-debug.apk
[ -f "$APK" ] && { echo "产物: $APK"; (sha256sum "$APK" 2>/dev/null || shasum -a 256 "$APK") | awk '{print "sha256:",$1}'; }
