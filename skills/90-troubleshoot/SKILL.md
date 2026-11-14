---
name: troubleshoot
description: 一条命令采集现场（环境、设备、日志、模块状态），用于"装不上""连不上""装了没反应"的第一次分诊。
---

# 90 故障排查

## 什么时候用

任何异常的第一步。**先采现场，再改东西**——否则改完就说不清是哪个动作生效的。

## 怎么做

```bash
bash scripts/collect.sh --out work/diag-$(date +%H%M)
```

产出：`env.txt`（版本快照）、`device.txt`（adb 状态）、`logcat.txt`（最近 2000 行）、`vector.txt`（CLI status，若有）、`apk.txt`（若给了 APK 路径）。

## 分诊表（BOOK 8.1–8.2）

| 现象 | 先查 | 常见原因 |
|---|---|---|
| 命令找不到 | `env.txt` | PATH / 解压未加 PATH |
| 版本不匹配 | `env.txt` | 多 JDK；frida 与 server 主版本不同 |
| `adb devices` 空 | `device.txt` | 未授权、线材、驱动 |
| 模块没反应 | `logcat.txt` | module.prop 不在包里；scope 未配；未 force-stop 重启 |
| REA 超时 | 会话日志 | 分不清 host deadline 与 provider 超时——处理完全不同 |
| 一切正常但结论怪 | 覆盖范围 | 很可能在看"页用尽"而不是"源完整" |

## 两种超时不要混（8.2）

| 报错 | 是谁到点 | 正确动作 |
|---|---|---|
| `timed out awaiting tools/call`（无结果） | 客户端 deadline | **不要重复同一调用**；调大 host 超时；必要时查 partial evidence |
| `provider_timeout`（有 REA 结果） | 服务端 | 按 remediation 处理；复用 partial evidence；先解决 incomplete cleanup |

## 边界

采集脚本只读：不删文件、不重启服务、不改模块状态。任何修复动作前先备份（`work/` 里留一份）。

→ 故障全表：[BOOK 8.1–8.4](../../BOOK.md)
