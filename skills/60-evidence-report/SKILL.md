---
name: evidence-report
description: 证据登记与可交付报告：结论必须绑证据、区分观测与推断、显式写未覆盖与未知。用于"报告被质疑""要给客户/上级交付"。
---

# 60 证据与报告

## 一条结论的最小结构（BOOK 7.1）

```
结论：<一句话，动词精确>
证据：<工具 + 定位（文件/函数/偏移/evidence_id）>
类型：观测 / 推断 / 未知     ← 三者必选其一
限制：<该证据类型的边界>
```

## 措辞对照（7.2，全文最容易被挑的地方）

| 不要写 | 改成 |
|---|---|
| 会调用 `checkSign()` | 存在对 `checkSign()` 的调用点（静态） |
| 使用的是 AES-128-CBC | 存在 `AES/CBC/PKCS5Padding` 的 `Cipher.getInstance` 调用点 |
| 没有反调试 | 在已覆盖范围内未发现反调试特征 |
| 服务端校验了签名 | 抓包可见签名参数；服务端行为未观测 |

## 怎么做

```bash
bash scripts/new-report.sh work/report.md "目标名" "分析范围"
```

生成骨架：范围 / 方法 / 结论表 / 限制与未覆盖 / 未知项 / 附录（版本快照 + evidence 清单）。

登记表用 `templates/finding-ledger.csv`：`id,conclusion,evidence,type,confidence,scope_gap,status`。

## 收尾自查（7.5）

- [ ] 每条结论都有 evidence 与 type
- [ ] "限制与未覆盖"不是空话（要写具体边界：哪个 so、哪个版本、哪段没跑）
- [ ] 未知项带 `required_authority`（需要什么级别的证据才能解决）
- [ ] 版本快照与设备型号在附录
- [ ] 没有任何"应该/大概率"出现在结论句里

→ 六字段与模板：[BOOK 7.1–7.5](../../BOOK.md) ｜ 未知项登记：[BOOK 7.4](../../BOOK.md)
