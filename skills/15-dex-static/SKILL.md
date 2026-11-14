---
name: dex-static
description: Java/DEX 层静态分析：用 jadx 反编译、按清单检索密钥与接口、产出可交付的 API 表。用于"逻辑在 Java 层"的目标。
---

# 15 Java / DEX 层静态分析

## 什么时候用

判型结果是原生 Java 应用，或需要先确认"签名/加密在 Java 还是 native"。

## 怎么做

```bash
bash scripts/jadx-run.sh samples/target.apk                 # 默认 --no-res，快
bash scripts/jadx-run.sh samples/target.apk --res           # 要资源/Manifest 时
bash scripts/jadx-run.sh samples/target.apk --deobf         # 只用于"读"，不要用于 hook
```

**铁律（BOOK 3.3 / C-07）**：如果下一步要用 Frida、JNI、unidbg 或任何运行时类加载，**首次反编译不要加 `--deobf`**。`--deobf` 生成的可读名在运行时不一定存在，先用它定位、再用原始名重新反编译去 hook。

## 检索清单（照抄，别凭感觉搜）

```bash
cd work/target/sources
grep -rn --include=*.java -E 'api[_-]?key|secret|password|token' . | head -50
grep -rn --include=*.java -E 'https?://[a-zA-Z0-9./_-]+' . | head -50
grep -rn --include=*.java -E 'Cipher\.getInstance|MessageDigest|Mac\.getInstance' .
grep -rn --include=*.java -E '@GET|@POST|@PUT|@DELETE|baseUrl|BASE_URL' .
grep -rn --include=*.java -E 'extends (Activity|Application|Service|BroadcastReceiver)' .
```

每个端点记成一行，字段固定：`METHOD /path | 来源 类:行 | BaseURL | 参数 | Header | Body | Response | 调用链`。

## 边界

- jadx 输出是**近似 Java**，不是原始源码；重混淆时可能不可编译。
- 方法反编译失败时 jadx **默认不输出该方法**——找不到时先加 `--show-bad-code` 复核，再下"这里没有"的结论。
- 静态看到的 URL/密钥可能是废弃分支，需与运行时抓包交叉验证。

→ 流程与 API 表模板：[BOOK 3.3](../../BOOK.md)
