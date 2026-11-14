---
name: apk-triage
description: 对一个 APK 做 3 分钟判型：是否加固、什么壳、什么引擎（原生/Unity/Flutter/H5/RN）、dex 规模、可疑权限。用于决定后面走哪条路线。
---

# 10 APK 判型

## 什么时候用

拿到 APK 的第一件事。**在装 jadx 之前就能做**——本技能只依赖 `unzip`/`file`/`sha256sum`。

## 怎么做

```bash
bash scripts/apk-triage.sh samples/target.apk
bash scripts/apk-triage.sh samples/target.apk --json > work/triage.json
```

脚本按顺序输出：

1. 指纹：SHA-256、体积、zip 条目数；
2. **dex 规模**：`classes*.dex` 数量与总大小（异常小的 dex + 超大 so 是壳的典型形态）；
3. **引擎特征**：`libil2cpp.so`+`global-metadata.dat`=Unity IL2CPP；`libflutter.so`+`libapp.so`=Flutter；`assets/index.android.bundle`=RN；`app-service.js`=uni-app；`assets/www`+`cordova.js`=Cordova；
4. **加固特征**：命中 BOOK 9.1 的特征表（so 名 / assets 目录 / Application 类名）；
5. 结论行：`路线 = 原生 / Unity / Flutter / H5 / RN / 未知`，`加固 = 未发现 / 疑似 X / 无法判定`。

## 判读纪律

- 命中特征只说明**存在该壳的文件**，不证明一定在用（可能残留）。判定为"疑似"，需要 dex 里 Application 类名交叉确认。
- `classes.dex` 很小（<100KB）而 `lib/` 很大 → 高概率方法抽取型壳，直接进 BOOK 5.2。
- 什么都没命中 ≠ 无壳：可能是自定义壳或纯 native 应用，标记 `无法判定` 而不是 `无壳`。

## 输出

给用户三行就够：

```
路线：<...>（依据：<文件名>）
加固：<...>（依据：<特征>，置信：高/中/低）
下一步：BOOK <章节>
```

→ 判型表：[BOOK 9.1](../../BOOK.md) ｜ 壳分级与脱壳：[BOOK 5.1–5.2](../../BOOK.md)
