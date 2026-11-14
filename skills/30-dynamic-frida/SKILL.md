---
name: dynamic-frida
description: 运行时观测与 hook：附加探针、方法级 hook、native 加载时机处理、日志锚点。用于静态不足、必须看运行时值的目标。
---

# 30 动态分析与 hook

## 什么时候用（BOOK 4.1 的四条触发条件）

1. 参数是运行时拼装、静态还原成本过高；
2. Java 调 native 做签名/token；
3. 自定义网络栈，静态找不到最终请求；
4. 需要"运行时值"作为证据（密钥、token、解密结果）。

不满足就先别上动态——静态能给的结论，动态只是更贵。

## 怎么做

```bash
# 0) 环境（同 DEPLOY §5）
adb devices -l ; frida --version ; adb shell "/data/local/tmp/frida-server --version"

# 1) 附加探针：只读，不改行为
bash scripts/run-frida.sh --package com.example.app --script hooks/probe.js

# 2) 方法级 hook 模板
bash scripts/run-frida.sh -p com.example.app -l hooks/cipher.js
bash scripts/run-frida.sh -f com.example.app -l hooks/cipher.js    # spawn 模式
```

**不要写 `--no-pause`**：现代 Frida CLI 没有这个参数，spawn 后脚本加载完会自动恢复。

## 三条硬规则

| 规则 | 原因 |
|---|---|
| 不要盲 hook `.init_array` / `JNI_OnLoad` / 构造器 | 一次性初始化，坏 hook 会在真实逻辑之前崩，或改掉时序掩盖现象 |
| native 模块未加载时，hook `android_dlopen_ext` 的 `onLeave`，按 `module.base` 去重 | 轮询既慢又可能错过；只按 path 去重会漏掉卸载重载 |
| 每条结论带锚点 | 模块基址、函数地址、脚本 SHA-256——否则别人无法复核（BOOK 4.7） |

## 输出（最低要求）

```
hook 点：<类.方法 / so!符号+偏移>
观测值：<入参 → 返回值>
锚点：base=0x... off=0x... script=<sha256前8位>
边界：仅本次进程/本次启动观测到
```

## 边界

- Frida 观测到的是**当前构建、当前设备、当前输入**的行为，不能外推成"这个 App 一定这样"。
- 反检测严格的目标可能直接退出：先看 BOOK 5.4，不要靠反复重启碰运气。

→ hook 配方与 SVC 表：[BOOK 4.4–4.5](../../BOOK.md) ｜ 反检测：[BOOK 5.4](../../BOOK.md)
