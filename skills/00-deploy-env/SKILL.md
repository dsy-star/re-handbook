---
name: deploy-env
description: 在新机器上判定逆向工程环境是否够用：分层自检、最小安装、版本匹配。用于"换电脑""环境报错""AI 首次接手仓库"。
---

# 00 环境自检与部署

## 什么时候用

- 新机器第一次干活；接手别人的机器；AI Agent 首次进入本仓库。
- 任何"命令找不到""版本不对""hook 连不上"的**第一步**——先自检，别猜。

## 怎么做

```bash
bash scripts/check-env.sh --layer L1        # 只要静态
bash scripts/check-env.sh --layer L2        # 要动态/模块
bash scripts/check-env.sh --tsv             # 给 AI 解析
```

输出 `TOOL<TAB>STATUS<TAB>DETAIL`，`STATUS ∈ {OK,MISSING,OPTIONAL,WARN}`；有 `MISSING` 退出码 1。

## 判定规则（不要自行放宽）

| 情况 | 动作 |
|---|---|
| 有 `MISSING` | 停。按 DETAIL 给的章节号装，一次一项，装完复跑 |
| 只有 `OPTIONAL` 缺 | 可以继续，但必须写进交付物的"限制" |
| `WARN` | 记录，不阻断（例：多 JDK 共存、PATH 有多份 jadx） |

## 安装

不在脚本里做。照 [DEPLOY.md](../../DEPLOY.md) §3–§6 执行。三条纪律：

1. 版本写死（REA `@6.9.0`），不用 `@latest`；
2. 不擅自升级全局 Node / JDK；
3. `npm i -g` 没权限就退到 `npx -y rea-agents@6.9.0`，不要 sudo。

## 边界

- 自检只能证明"命令存在且版本可读"，**不能证明它能干活**（jadx 内存不足仍会 OOM）。
- 设备侧（frida-server 是否在跑、adb 是否授权）只有 `--layer L2` 的 WARN 级提示，需人工确认。

→ 详细部署与回滚：[DEPLOY.md](../../DEPLOY.md) ｜ 跨平台坑：[BOOK 1.6](../../BOOK.md)
