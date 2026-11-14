# skills/ — 按技能分类的工具与规程

结构照搬「一目录一技能」：每个目录一个 `SKILL.md`（何时用、怎么做、边界），`scripts/` 放可直接跑的脚本，`templates/` 放可直接抄的模板。

编号即阅读顺序，也是依赖顺序：**00 装环境 → 10 判型 → 15/20 静态 → 30 动态 → 40 脱壳/校验 → 50 模块 → 60 交付 → 90 排障**。

| 目录 | 一句话 | 对应 BOOK | 有自己的脚本 |
|---|---|---|---|
| `00-deploy-env` | 环境自检与最小安装判定 | 1.1 / 1.6 / 8.1 | ✅ `check-env.sh` |
| `10-apk-triage` | APK 判型：壳 / 引擎 / dex 规模 | 2.1 / 9.1 | ✅ `apk-triage.sh` |
| `15-dex-static` | Java/DEX 层：反编译与检索 | 3.3 | ✅ `jadx-run.sh` |
| `20-native-static` | ELF 勘察、JNI 导出、符号线索 | 3.4 | ✅ `elf-survey.sh` |
| `30-dynamic-frida` | 附加探针与 hook 模板 | 4.1–4.5 | ✅ `run-frida.sh` + `hooks/` |
| `40-unpack-bypass` | 脱壳产物校验、模块包自检 | 5.1–5.6 | ✅ `verify-apk.sh` / `check-dump.sh` |
| `50-module-dev` | 模块模板、构建、启用、验证 | 6.1–6.8 | ✅ 4 个脚本 + `templates/` |
| `60-evidence-report` | 证据登记与报告 | 7.1–7.5 | ✅ `new-report.sh` + 模板 |
| `90-troubleshoot` | 故障采集（一条命令打包现场） | 8.1–8.4 | ✅ `collect.sh` |

## 使用约定

- 脚本都是 bash，**不交互**、不改系统、不联网（除非脚本头注明）。
- 只有 `00` 会提示安装命令，**不会替你执行安装**。
- 每个脚本 `--help` 有用法；没有 `--help` 的直接看文件头 10 行。
- Windows 用 Git Bash，路径写 `D:/x` 或 `/d/x`。
