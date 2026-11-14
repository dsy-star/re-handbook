---
name: unpack-bypass
description: 脱壳与产物校验：判断要不要脱、脱完怎么验证是真 dex、模块包与重打包产物怎么自检。用于有壳目标与"改完不生效"的场景。
---

# 40 脱壳与产物校验

## 先回答"要不要脱"（BOOK 5.6）

| 你的目标 | 需要脱壳吗 |
|---|---|
| 只要协议/接口 | 通常**不需要**：抓包 + hook 出站请求更快 |
| 要读被抽取的方法体 | 需要（方法抽取型壳） |
| 只要改一个返回值 | 不一定：Frida 或 smali 定位到调用点即可 |
| 要静态审计全量代码 | 需要，且要接受"可能脱不全" |

## 脱壳后的三项校验（必做）

```bash
# 1) 是不是真 dex（magic 035/036/037/038/039）
bash scripts/check-dump.sh work/dump/

# 2) 能不能被解析（header checksum/signature 是否被壳改坏）
jadx --no-res -d work/dump-src work/dump/classes.dex

# 3) 方法体是否为空（抽取型壳的典型残留）
grep -rc "native " work/dump-src/sources 2>/dev/null | head
```

三条里任一失败，就写"脱壳不完整"，**不要**基于残缺 dex 下"该方法不存在"的结论。

## 重打包 / 模块包自检

```bash
bash scripts/verify-apk.sh out/app-debug.apk --module   # 模块三件套
bash scripts/verify-apk.sh out/patched.apk             # 普通重打包：对齐+签名
```

模块包必须满足：`META-INF/xposed/module.prop`、`META-INF/xposed/java_init.list` 存在；`io/github/libxposed/**` **不得**被打进 APK（桩只能是 `compileOnly`）。

## 边界

- 通用脱壳机对一代壳有效，方法抽取型（二代）需要主动调用，VMP 基本只能绕过不能还原（BOOK 5.1–5.2）。
- 脱壳产物是**派生物**，永远放 `work/`，`samples/` 保持原始哈希不变。

→ 壳特征与分级：[BOOK 9.1](../../BOOK.md) ｜ 三条脱壳路线：[BOOK 5.2](../../BOOK.md)
