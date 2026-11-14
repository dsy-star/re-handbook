---
name: native-static
description: ELF/.so 静态勘察：架构与依赖、JNI 导出与 RegisterNatives、加密与网络导入、可疑字符串。用于判"逻辑在 native"之后的第一步。
---

# 20 Native 层静态分析

## 什么时候用

- 判型发现 `lib/*/lib*.so` 且 Java 层只是壳。
- 需要回答：签名/加密在 native 吗？是静态导出还是动态注册？

## 怎么做

```bash
bash scripts/elf-survey.sh work/target/lib/arm64-v8a/libnative.so
bash scripts/elf-survey.sh <so> --jni        # 只看 JNI 相关
```

脚本顺序（对应 BOOK 3.4 的标准序列）：

1. `file` 定架构；`readelf -d` 看依赖与 SONAME；
2. 动态符号：`Java_*`（静态注册）与 `JNI_OnLoad`（可能存在动态注册）；
3. 导入表里找 `__android_log_print`、`SSL_*`、`socket/connect`、`EVP_*`、`AES_*`；
4. `strings` 找 URL/host/日志 tag/`RegisterNatives`/`encrypt`/`sign`；
5. 结论：静态注册 / 动态注册 / 无法判定。

## 判读

| 现象 | 含义 | 下一步 |
|---|---|---|
| 有 `Java_*` 导出 | 静态注册，函数名即类名+方法 | 直接定位，`pdf @ sym.Java_...` |
| 只有 `JNI_OnLoad` | 大概率 `RegisterNatives` 动态注册 | 运行时 hook 看注册表，或读 `JNI_OnLoad` 找 `RegisterNatives` 调用点 |
| 少数超大函数（>10KB） | 混淆（控制流平坦化） | 别硬读伪代码，转运行时（BOOK 3.4） |
| 导入表无 crypto 但字符串有 AES SBox | 算法自实现/魔改 | 按常量定位，见 BOOK 9.3 |

## 边界

- 静态能看到"存在 `RegisterNatives` 调用点"，**不能**推出"运行时注册了哪个方法"——那是运行时证据。
- 符号被 strip 后，名字要靠魔数/参数模式/调用关系推，结论必须带置信度。

→ 符号恢复与结构体：[BOOK 3.4](../../BOOK.md) ｜ 去混淆：[BOOK 3.4 / 5.5](../../BOOK.md)
