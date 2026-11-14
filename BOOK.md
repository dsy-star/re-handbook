# 逆向工程与模块开发工具书

> 版本：v1.0（2026-11-14）
> 适用范围：Android / Native / 桌面与 Web 应用的逆向分析，以及 Xposed / Vector 模块开发、调试与验证。
> 编纂方式：以三处来源交叉整合，逐条标注来源，冲突处按「REA 优先」裁决并留痕。
>
> 仓库位置：本文件是整版正文（BOOK.md）；部署与自检见 [DEPLOY.md](DEPLOY.md)；分类工具见 [skills/](skills/)；给 AI 的读取契约见 [AGENTS.md](AGENTS.md)。

---

## 0. 阅读前必读

### 0.1 这份文档是什么

一份**可执行**的逆向与模块开发手册，而不是资料索引。它回答四类问题：

1. 拿到一个目标（APK / SO / Electron 应用 / 固件 / 抓包 / 数据库），**第一步该做什么**；
2. 用什么工具、什么参数、按什么顺序做，**做到什么程度算有结论**；
3. 结论如何**取证**（证据类型、权威度、限制、未知项），如何写成可复核的报告；
4. 要交付一个 **Vector / libxposed 模块**时，工程结构、构建前置、安装与验证怎么做。

### 0.2 来源与标注约定

| 代号 | 来源 | 实际路径 | 形态 |
|---|---|---|---|
| **A** | Android 逆向工程技能合集（47 个技能目录） | `E:\Download\Archive\-skills-main\-skills-main\Android逆向工程技能完整合集` | 263 个文件，约 4.9 MB，以 `SKILL.md` + `scripts/` + `docs/` 为主 |
| **B** | REA（Reverse Engineer Anything） | `E:\WorkSpace\Code\GitRepo\rea-compare\v690\package`（`rea-agents@6.9.0`） | MCP 服务端 + CLI + 技能文档（README 33 KB、技能正文 43 KB、references 240 KB） |
| **C** | vector-xposed-module-skill | `C:\Users\ADU\.codex\skills\vector-xposed-module-skill` | 单技能，正文约 8 KB，含模板与 CLI 自动化规则 |

正文中：
- 段落末尾的 `（A）`/`（B）`/`（C）` 表示该结论的出处；多来源一致时写 `（A/B）`。
- `【裁决】` 标记三处来源冲突处，并给出取舍理由。
- `（待补充：…）` 表示来源中缺失、互相矛盾或无法确认的信息，**不做推测填充**。
- 命令中的 `TARGET`、`APK`、`SAMPLE`、`PKG`、`MODULE_PKG`、`OUT_DIR` 为占位符，按实际替换。

### 0.3 三条使用原则（关键结论前置）

1. **先路由，再动手**：目标类型决定工具链。用错工具链的代价远大于多花 2 分钟分类（B）。
2. **静态优先，动态补证**：静态能回答的问题不要上运行时；运行时只用于静态无法回答的行为问题，且必须声明「这是运行时观测」（B）。
3. **结论必须带证据等级**：observed（观测）/ derived（派生）/ inferred（推断）/ unknown（未知），不可混写；静态分析**永不**等于「观测到执行」（B）。

### 0.4 三条常见错误（先避免，能省数小时）

| 错误 | 后果 | 正确做法 | 来源 |
|---|---|---|---|
| 一上来就对加固 APK 用 jadx 找业务代码 | 只看到壳的 stub，误判「应用没逻辑」 | 先做壳识别（`lib/` 的 so 名、assets 特征、Application 类名），再决定脱壳方案 | A |
| 把 `analyze_function` 的 summary 直接喂给 `compare_functions` | 调用被拒（summary 不是完整 dossier） | 传 `normalized_result.parent_evidence_id` 作为 `retained-evidence` | B |
| 模块里把 `io.github.libxposed.*` 打进 APK | 类冲突，模块加载失败或行为异常 | 只用 `compileOnly` 桩，构建后用 `unzip -l` 复核 | C |

---

## 目录

- [0. 阅读前必读](#0-阅读前必读)
  - [0.1 这份文档是什么](#01-这份文档是什么) · [0.2 来源与标注约定](#02-来源与标注约定) · [0.3 三条使用原则](#03-三条使用原则关键结论前置) · [0.4 三条常见错误](#04-三条常见错误先避免能省数小时)
- [1. 环境与工具链](#1-环境与工具链)
  - [1.1 运行时前置](#11-运行时前置) · [1.2 分析引擎与提供方](#12-分析引擎与提供方provider) · [1.3 MCP 与 Agent 集成](#13-mcp-与-agent-集成) · [1.4 设备侧](#14-设备侧android) · [1.5 工作区与产物规范](#15-工作区与产物规范) · [1.6 换机器 / 交接](#16-换机器--交接文档能不能用还缺什么)
- [2. 目标识别与路由](#2-目标识别与路由)
  - [2.1 判定树](#21-判定树按首字节文件结构而不是扩展名) · [2.2 起手三问](#22-起手三问省掉-80-的返工) · [2.3 Android 三条子路线](#23-android-路线三条子路线不要混用) · [2.4 路由时的三个判断](#24-路由时的三个判断不要在这里展开特征库)
- [3. 静态分析流程](#3-静态分析流程)
  - [3.1 通用六步法](#31-通用六步法) · [3.2 包里有什么](#32-第一步永远是包里有什么) · [3.3 Java / DEX 层](#33-java--dex-层) · [3.4 Native 层](#34-native-层elf--mach-o--pe--so) · [3.5 其他目标类型](#35-其他目标类型的静态要点) · [3.6 静态结论的三条硬边界](#36-静态结论的三条硬边界b)
- [4. 动态分析与运行时观测](#4-动态分析与运行时观测)
  - [4.1 何时上动态](#41-何时上动态合并-ab-的判据) · [4.2 设备与 Frida 基线](#42-设备与-frida-基线) · [4.3 hook 点选择](#43-hook-点选择先时机后位置) · [4.4 Java 层 hook 配方](#44-java-层-hook-配方) · [4.5 Native 与 syscall](#45-native-观测与-syscall-层) · [4.6 抓包与证书绑定](#46-抓包与证书绑定) · [4.7 运行时结论的锚点](#47-运行时结论的锚点补-a-的短板) · [4.8 AgentEnv](#48-agentenv把一次录制变成可重放环境b)
- [5. 加壳、脱壳、绕过与补丁](#5-加壳脱壳绕过与补丁)
  - [5.1 壳识别与分级](#51-壳识别与分级) · [5.2 三条脱壳路线](#52-三条脱壳路线) · [5.3 非标准运行时](#53-非标准运行时的脱壳) · [5.4 反检测](#54-反检测先分层定位再决定手段) · [5.5 补丁的三种落点](#55-补丁的三种落点) · [5.6 【裁决】脱壳是否必经](#56-裁决脱壳是否是必经步骤)
- [6. Android 模块开发（Xposed / Vector / libxposed）](#6-android-模块开发xposed--vector--libxposed)
  - [6.1 两代规范差异](#61-两代规范的差异一眼判断该用哪套) · [6.2 工程结构](#62-工程结构现代) · [6.3 入口与时序](#63-入口与时序最容易做错的一步) · [6.4 构建前置](#64-构建前置三个不要假设) · [6.5 安装与启用](#65-安装与启用含版本门禁) · [6.6 验证序列](#66-验证序列照抄即可) · [6.7 免 root 替代](#67-免-root-的三条替代路径a) · [6.8 失败对照表](#68-模块开发常见失败对照表)
- [7. 证据、比较与交付](#7-证据比较与交付)
  - [7.1 证据模型](#71-证据模型六个字段) · [7.2 措辞规范](#72-结论的措辞规范) · [7.3 比较与变更分析](#73-比较与变更分析) · [7.4 未知项登记](#74-未知项登记把没搞清变成资产) · [7.5 交付物模板](#75-交付物模板) · [7.6 工作区与产物规范](#76-工作区与产物规范)
- [8. 故障排查与常见问题](#8-故障排查与常见问题)
  - [8.1 环境类](#81-环境类) · [8.2 REA 侧两种超时](#82-rea-侧两种超时不要混) · [8.3 十八反模式](#83-十八反模式照单避免) · [8.4 高频现象](#84-逆向过程中的高频现象)
- [9. 附录](#9-附录)
  - [9.1 加固特征库与判型卡](#91-加固特征库与判型卡) · [9.2 工具—目标矩阵](#92-工具目标矩阵) · [9.3 命令速查](#93-命令速查) · [9.4 来源覆盖表](#94-来源覆盖表) · [9.5 冲突登记表](#95-冲突登记表) · [9.6 待补充清单](#96-待补充清单) · [9.7 舍弃清单](#97-舍弃清单不纳入正文的内容与原因) · [9.8 社区项目索引](#98-社区项目索引与整合建议)

---

## 1. 环境与工具链

> **本章结论**：三处来源对「前置条件」的表述最不一致，也最容易踩坑。把环境拆成四层——运行时（Node/JDK/Python）、引擎（Ghidra/Hopper/IDA/Kuna/JADX）、设备侧（adb/frida-server/root/LSPosed）、构建侧（Android SDK/Gradle Wrapper）——逐层验收，比一次性装全套可靠。

### 1.1 运行时前置

| 组件 | 版本要求 | 用途 | 来源 |
|---|---|---|---|
| Node.js | `^22.23.4 \|\| ^24.22.1 \|\| >=26.12.1`（REA 6.9.0 `engines`） | REA MCP/CLI 运行；静态 JS/Electron 分析无需 native 引擎 | B |
| Node.js（SQLite 工具） | 24.x ≥ 24.15 或 26+，需原生 SQLite limits | `inspect_sqlite_database` | B |
| JDK | **17**（AGP 8.x 硬性要求；REA 的 JADX 提供方同样要求 Java 17+） | 构建模块、JADX 反编译 | B/C |
| Python 3 | 版本未在来源中限定 | `inspect_binary_layout` / 崩溃分析依赖 pwntools 4.15.0、pyelftools 0.33、Unicorn 2.1.2 | B |
| adb | 调用方自备（REA 不安装 platform-tools） | 设备枚举、安装、日志、拉取 APK | B |

要点：
- **不要假设全局 `gradle` 可用**（C）。模板自带 Gradle 8.7 wrapper，构建顺序为 `./build_debug.sh` → `./gradlew :app:assembleDebug` → `GRADLEW=/path/to/gradlew ./build_debug.sh`，最后才回退全局 `gradle`；都没有就停下来提示用户补 wrapper（C）。
- **不要假设当前 `java` 可用**（C）。`build_debug.sh` 的 JDK 17 探测顺序：`JDK_HOME` → `JAVA_HOME` → `/usr/libexec/java_home -v 17` → Homebrew `openjdk@17`/`temurin@17` 路径 → `/Library/Java/JavaVirtualMachines/*/Contents/Home` → PATH 上的 `java`（且必须为 17）。调用 Gradle 时显式传入：
  ```bash
  ./gradlew -Dorg.gradle.java.home="$JDK17_HOME" :app:assembleDebug
  ```
- **不要假设 Android SDK 可被发现**（C）。探测顺序：`ANDROID_HOME` → `ANDROID_SDK_ROOT` → `local.properties` 的 `sdk.dir` → `$HOME/Library/Android/sdk` → `$HOME/Android/Sdk` → `$HOME/Android/sdk`；命中后写回 `local.properties`：
  ```properties
  sdk.dir=/path/to/android-sdk
  ```

### 1.2 分析引擎与提供方（provider）

REA 把「分析引擎」抽象成 provider，**同一操作在不同引擎上的能力不同**，因此「用哪个引擎」是每次任务的显式决策，而不是默认值（B）。

| 引擎 | REA 中的角色 | 关键要求 | 来源 |
|---|---|---|---|
| Ghidra | 深分析主力：伪代码、汇编、xref、基本块；支持 16-bit DOS/COM、MIPS/PPC/RISC-V/6502/M68K 等 | 需本机已安装；大二进制用 `REA_GHIDRA_STARTUP_TIMEOUT_MS` 放宽启动超时 | B |
| Hopper | macOS 侧深分析；REA 会按需启动 | 首次运行可能弹 demo/license 对话框，需在同一用户会话先完成；`REA_HOPPER_STARTUP_TIMEOUT_MS` | B |
| IDA | 深分析；可选原生 MCP bridge | 本机安装；`verify:ida` 自检 | B |
| Kuna | 反编译器提供方 | 本机安装 | B |
| JADX（headless MCP JAR） | Android DEX/Java 反编译 | **JAR 0.7.1 + Java 17+**；`REA_JADX_MCP_JAR` 指定绝对路径；`REA_JADX_HEAP_MIB`、`REA_JADX_OPERATION_TIMEOUT_MS`（默认 120000 ms） | B |
| JEB | 工程级 Android/iOS 分析 | 调用方自行启动 JEB 客户端并暴露 MCP；`REA_JEB_MCP_URL`（默认 `http://127.0.0.1:8425/mcp`） | B |
| Apktool | 资源解码（manifest、strings、locale） | 调用方提供启动器；`REA_APKTOOL_COMMAND` 或 PATH | B |
| objdump / Rizin | 离线反汇编与调试 | 调用方提供 `objdump`/`rizin`；REA 不安装、不升级 | B |
| Frida | 运行时插桩（脚本、spawn/attach、持久会话） | 设备侧 `frida-server` 版本与本地 Frida 匹配（A 的实践），REA 侧按会话管理 | A/B |
| Chrome 系浏览器 | Web/Electron 观测（CDP） | 本机 Chrome/Chromium；`list_browser_targets` 只接受回环 CDP 端点 | B |

> **【裁决】引擎之争**：A 把 IDA/IDAPython 当作 native 逆向的默认主工具；B 则把 Ghidra/Hopper/IDA/Kuna 并列为 provider，按目标与操作选择，且明确「provider 选择失败不做自动回退」。
> **取舍：以 B 为准。** 理由：A 的 IDA 中心论是单机工具视角，B 的多 provider 模型能覆盖更多格式（DOS/COM、MIPS、RISC-V、GameCube DOL、IL2CPP 元数据等），且「选择即绑定」可避免同一结论混用两个引擎的坐标系。IDA 仍保留为可选主力，尤其在需要 IDAPython 批量分析时（A 的 `IDAPython逆向`、`IDA智能补丁` 仍有效）。

**引擎侧的社区对照**（选型时先看这里，再看 [9.8](#98-社区项目索引与整合建议)）：Ghidra 100.0k、radare2 25.4k、Cutter 20.2k、rizin 4.2k、Unicorn 9.6k、Capstone 9.2k（star 为 2026-11-14 快照）。它们与上表的对应关系是：**Ghidra = 本表第一行的深分析 provider**；**rizin/Cutter = 不需要 provider 时的兜底勘察**（3.4 的 `.so` 五步就用它）；**Unicorn/Capstone = 片段模拟与反汇编的底座**（3.4 的 Unicorn 五原则依赖它们）。换句话说，B 抽象的是"用哪个引擎"，社区项目决定了"引擎能做到什么"。

### 1.3 MCP 与 Agent 集成

最小可用配置（B）：

```json
{
  "mcpServers": {
    "rea": {
      "command": "npx",
      "args": ["-y", "rea-agents@6.9.0", "mcp"]
    }
  }
}
```

安装与更新：
```bash
npx rea-agents setup          # 注册 MCP + 安装配套技能，改前自动备份
rea update                    # 已全局安装时更新（别名 rea --update）
npx rea-agents@latest setup   # 用 npx 时的刷新方式
```

两个容易忽略的开关（B）：
- `REA_MCP_INPUT_SCHEMA_PROFILE=full`：默认下发「紧凑输入 schema」以省上下文；需要完整字段说明时切 `full`。两者工具集与校验一致。
- `REA_MCP_OUTPUT_SCHEMA_PROFILE=compact|off`：客户端对 `tools/list` 帧有上限时，压缩或关闭输出 schema。

技能与 MCP 是两件事（B）：技能只提供「调查指令」，不注册 MCP、不安装引擎；插件式安装（Claude Code / Codex / Cursor Marketplace）自带 `rea` server，属于 `rea setup`/`rea doctor` 管理范围之外。

### 1.4 设备侧（Android）

| 项 | 要求/做法 | 来源 |
|---|---|---|
| 连接 | `adb devices -l` 确认 serial 与 transport；REA 的 adb 工具全部要求显式 `serial` | B |
| root | 脱壳、内核 Hook、`su -c` 调用 Vector CLI 需要 root；免 Root Hook 走 VirtualApp/沙箱方案 | A/C |
| frida-server | 版本与本地 `frida` 客户端匹配；不匹配表现为 attach 失败或脚本静默不生效 | A |
| 模块框架 | LSPosed / Vector；Vector 新版需 `targetApiVersion=101` 才按 modern 加载 | C |
| Vector CLI | `/data/adb/lspd/cli`；**仅当 `Version Code >= 3043`** 才允许自动 enable/scope 变更，否则退回手动操作 | C |

### 1.5 工作区与产物规范

- **样本隔离**：原包与派生物分目录存放（`samples/`、`work/`、`out/`），所有修改保留可回滚副本（B 的「keep original and derived artifacts separate」原则；A 的重打包流程同样要求保留原 APK）。
- **证据落盘**：REA 的引用只在当前 MCP 连接内有效，会话结束即失效；需要长期保存时先 `export_evidence_bundle`（或 `reset_investigation --save_path`）再关闭（B）。
- **命名**：模块工程用 `<模块名>/`，产物 `app-debug.apk`，日志过滤标签固定（C 的 `VectorToastModule`）。

（待补充：A 未给出统一的目录规范；本节目录名为本工具书约定，不属任何来源的硬性要求。）

---

### 1.6 换机器 / 交接：文档能不能用、还缺什么

**文档本身零依赖**：单文件 Markdown，无图片、无外链资源，目录与交叉引用都是相对锚点。VS Code、Typora、Obsidian、GitHub、手机阅读器打开即可，不需要联网、不需要构建。

**但流程有依赖**，按你打算做到哪一步分三层：

| 层 | 目标 | 新机器需要装 | 耗时 |
|---|---|---|---|
| **L0 只读** | 查流程、判据、报告模板 | 一个 Markdown 阅读器 | 0 |
| **L1 静态** | 3.3 / 3.4（APK、ELF） | JDK 17+、jadx、apktool、rizin（或直接用 REA，由它调这些工具） | 15–30 分钟 |
| **L2 动态与模块** | 4.x / 5.x / 6.x | L1 + adb + 平台工具 + `frida-tools` 与设备端 `frida-server`（**同主版本**）+ Android SDK + Gradle（模板自带 wrapper） | 1–2 小时 |

**跨平台会卡住的四件事**（第 1.1 节的前置表是"要什么"，这里是"在哪会绊倒"）：

| 平台 | 坑 | 处理 |
|---|---|---|
| Windows | 本书命令按 bash 写；`/tmp` 不是合法工作目录 | 用 Git Bash / MSYS；路径写 `D:/x` 或 `/d/x` |
| Windows | C 的 JDK 探测顺序（`/usr/libexec/java_home`、Homebrew 路径）是 macOS 取向 | **手动设 `JDK_HOME` 指向 JDK 17**；Gradle 显式传 `-Dorg.gradle.java.home`（待补充：C 未给 Windows 专用探测逻辑） |
| macOS | 多版本 JDK 共存时 `java -version` 常指向错的版本 | 按 6.4 的探测顺序取 17；首次运行 Hopper 会弹 demo/license 对话框，需先在同一用户会话点掉 |
| Linux | 固件与抓包路线依赖 Linux 专用工具 | `binwalk`/`unblob`/`tshark` + `prlimit`（util-linux）与 `procps`；Windows 上这两条路线直接放弃 |
| 全平台 | REA 的 Node 版本、Frida 的主版本匹配 | Node `^22.23.4 \|\| ^24.22.1 \|\| >=26.12.1`；`frida` 与 `frida-server` 主版本必须一致；adb 需设备已授权 |

**十分钟自检**（新机器上先跑这一组，再谈分析）：

```bash
# 文档能不能读
ls -l 逆向工程与模块开发工具书.md

# L1 静态链
java -version 2>&1 | head -1          # 需 17
jadx --version ; apktool --version ; rizin -v
rea --version 2>/dev/null ; node --version

# L2 动态链
adb devices -l
frida --version ; adb shell "/data/local/tmp/frida-server --version" 2>/dev/null

# L2 模块链
echo "$JDK_HOME" ; echo "$ANDROID_HOME"
```

任何一行失败，就停在这一层——不要带着半套环境往下做，那是最容易得出错误结论的状态。

**交接给别人时的清单**（与 7.6 的产物规范同源）：

1. `samples/`（只读原始样本）+ 每个样本的 SHA-256；
2. `work/`（解包、补丁副本）与每次改动的原字节/回滚点；
3. 报告正文 + evidence bundle（`export_evidence_bundle` 的产物）；
4. 本工具书版本（v1.0）与 9.8 的 star 快照日期——**不然对方无法判断哪些结论已经过期**；
5. 9.6 里与本项目相关的"待补充"条目——明确告诉对方"这里我们也没搞清"。

---

## 2. 目标识别与路由

> **本章结论**：**先判类型，再选第一个工具**。REA 的路由表（B）已覆盖 30+ 类目标；A 的判型经验（加固特征、引擎特征）用于补齐「同一类型内部的下一步」。

### 2.1 判定树（按首字节/文件结构，而不是扩展名）

```
目标
├─ 目录 / .app / .asar ────────────► JS/Electron：analyze_javascript_application
├─ 压缩包/安装包（ZIP/APK/IPA/MSIX/AppX/DMG/PyInstaller）
│    └─► open_binary + inspect_artifact（先 summary）
│         ├─ 含 classes.dex ──────► Android 路线（2.3）
│         ├─ 含 lib/*/libapp.so ──► Flutter 路线（2.5）
│         └─ 含 global-metadata.dat ► Unity IL2CPP 路线（2.5）
├─ ELF / Mach-O / PE ──────────────► open_binary（native 会话）→ 3.3
├─ .NET 程序集 ────────────────────► inspect_managed_artifact（纯静态，无需引擎）
├─ 固件镜像 ───────────────────────► inspect_firmware_regions → extract_firmware（Linux + binwalk/unblob）
├─ .pcap/.pcapng ──────────────────► inspect_pcap_capture（Linux + tshark/capinfos）
├─ HAR / SAZ / qlog ───────────────► inspect_web_network_capture
├─ .sqlite/.db ────────────────────► inspect_sqlite_database（带 WAL 快照）
├─ .wasm ──────────────────────────► inspect_wasm_artifact（WABT 1.0.42）
├─ EVM 字节码 ─────────────────────► inspect_evm_interface（Linux x64）
└─ 网页 / 运行中的应用 ─────────────► CDP：list_browser_targets → inspect_web_page
```

（路由主干来自 B 的 `Route the target first`；`.so`/`assets` 的内部判型来自 A 的壳识别与引擎识别经验。）

### 2.2 起手三问（省掉 80% 的返工）

1. **这个结论依赖「出厂产物」还是「运行时行为」？** 依赖产物 → 静态路线；依赖行为 → 运行时路线并声明证据类型（B）。
2. **目标是完整源码仓库吗？** 是 → 用普通仓库工具，**不要**跑 REA 与 provider 自检（B 明确要求跳过）。
3. **有没有保护层（壳/混淆/VMP/反调试）？** 有 → 先做第 5 章的识别，否则后续所有静态结论都可能只描述壳（A）。

### 2.3 Android 路线（三条子路线，不要混用）

| 子路线 | 首个工具 | 能回答 | 不能回答 | 来源 |
|---|---|---|---|---|
| 包与声明 | `inspect_android_package` | 包名、SDK、权限、组件、类/资源计数、解码后的 manifest | 运行行为、加固后的真实逻辑 | B |
| 类与方法 | `search_android_classes` → `inspect_android_class` → `inspect_android_method` → `trace_android_references` | 成员、重载、方法体（JADX）、入向静态引用 | JNI 实际注册、反射调用、加密字符串 | B |
| 资源 | Apktool 解码：manifest、strings、locale、版本事实 | 文案、多语言、资源引用 | 代码逻辑 | B |
| 设备 | `list_adb_*` / `pull_adb_package` / `read_adb_logcat` / `capture_adb_screen` | 已安装包、进程、日志、截图、APK 拉取 | 反编译（需回到类/方法路线） | B |

JADX 前置（B）：headless JADX MCP JAR **0.7.1** + **Java 17+**；`REA_JADX_MCP_JAR` 指向绝对路径。R8/ProGuard 构建可传 `mapping_path` 做符号归一，但 **REA 不验证 mapping 是否属于该 APK 构建**——报告中必须写这一限制。

### 2.4 路由时的三个判断（不要在这里展开特征库）

| 判断 | 观测点 | 路由结果 |
|---|---|---|
| 是否加固 | `lib/<abi>/` 出现 `libjiagu*`、`libDexHelper*`、`libshellx*`、`ijiami*`、`libchaosvmp*` 等；或 `Application` 类名是壳的包装类 | 有壳 → 先做 [9.1 判型卡](#91-加固特征库与判型卡)，再按 [5.6](#56-裁决脱壳是否是必经步骤) 决定是否脱壳；无壳 → 直接 3.3 |
| 是否特殊运行时 | `libil2cpp.so` + `global-metadata.dat`（Unity IL2CPP）；`libflutter.so` + `libapp.so`（Flutter）；`assets/index.android.bundle`（RN）、`app-service.js`（uni-app） | 走 [5.3](#53-非标准运行时的脱壳) 的对应支路，不要按普通 Java 应用处理 |
| 逻辑在哪一层 | 反编译出的业务类是否只有薄壳、关键方法是否 `native` | Java 层有实现 → 3.3；只有 native → 3.4；两层都只有转发 → 4.1 上动态 |

> 壳特征全表在 [5.1](#51-壳识别与分级)（含分级），判型顺序与误判处理在 [9.1](#91-加固特征库与判型卡)。本节只做路由决策，不复述特征。

---

## 3. 静态分析流程

> **本章结论**：静态分析不是"打开工具随便看"，而是一条**假设驱动的取证链**：问题清单 → 每问需要什么证据 → 最小 inventory 起步 → 只在出现具体缺口时扩展。REA 把这条链写成了硬约束（B），A 的 Android/native 实操补齐了"具体看什么"（A）。

### 3.1 通用六步法

| 步 | 动作 | 判据/产物 | 来源 |
|---|---|---|---|
| 1 | 把请求拆成问题清单，并写明每个答案需要哪类证据 | 一句一问，避免"帮我看看这个 App" | B |
| 2 | 先查已有会话/artifact 身份/bookmarks/历史证据 | 命中就复用，不重复分析 | B |
| 3 | 从最小的 overview/inventory 起步 | 只拿到"有哪些东西"，不深挖 | B |
| 4 | 按假设批量取证据 | 一批只服务一个假设 | B |
| 5 | 出现具体缺口才扩展 | 缺口写成一句可检验的问题 | B |
| 6 | 维护 finding ledger | 结论 → evidence_id、置信度、证据类型、搜索边界、剩余未知 | B |

**格式感知原则**（B）：不得从文件名、字符串或布局推断行为；必须用对应格式的解析器（PE 用 PE 解析器、APK 用 DEX 解析器、PCK 用 PCK 解析器）。

### 3.2 第一步永远是"包里有什么"

| 目标 | 首个调用 | 关键输出 |
|---|---|---|
| APK / IPA / ZIP / MSIX / DMG / ASAR | `open_binary` → `inspect_artifact(detail:"summary")` | 组件路径、内容哈希、完整性矛盾、runtime-family hints |
| 目录形态的 Electron 应用 | `analyze_javascript_application(detail:"summary")` | 模块图、路由候选、端点候选、vendor 指纹 |
| 单个 native 文件 | `open_binary` → `binary_overview` | 段、过程数、字符串数、image base |
| .NET 程序集 | `inspect_managed_artifact(detail:"summary")` | 模块/MVID、类型与方法计数、框架、覆盖问题 |
| 固件镜像 | `inspect_firmware_regions` | 签名候选、偏移、长度、置信度 |

> **分页纪律**（B）：`inspect_artifact` 的 inventory 用 `view {kind:"inventory", collection:"occurrences|nodes|edges|integrity_contradictions", logical_paths:[...]}`；`logical_paths` 省略=全部分页，`[]`=一个都不选。**页用尽 ≠ 源完整**：`source_complete` 与 page exhaustion 是两个维度，部分源里"没匹配到"不等于"不存在"。

### 3.3 Java / DEX 层

**静态主力**（A）：jadx 出 Java 便于阅读，apktool 出资源与 smali 便于回编，两者互补。

```bash
jadx --no-res -j 8 app.apk -d out          # 只要代码，快 3–5 倍
jadx --deobf app.apk -d out                # 仅用于阅读；下一步要 hook 就不要加
apktool d app.apk -o app_src -f            # 资源 + smali
```

> **【裁决】`--deobf` 的使用边界**：A 的 `Jadx反编译` 建议"生产应用总是加 `--deobf`"，而 A 的 `Android逆向工程` 明确"下一步要用 Frida/JNI/unidiff 时首次不要加"。**取后者**：`--deobf` 生成的可读别名在运行时不保证存在，跨到动态阶段会造成"类找不到"的假故障。规则：**静态阅读可以 deobf，动态/hook 前必须用原始名再跑一次**（A 内部矛盾，按更具体的场景规则裁决）。

**结构分析四件事**（A）：
1. manifest：launcher Activity、全部组件、权限、`android:name` 的 Application；
2. 包结构：`api`/`network`/`data`/`repository`/`service`/`retrofit`/`http`；
3. 架构模式：MVP（Presenter）/ MVVM（ViewModel+LiveData/StateFlow）/ Clean（domain/data/presentation）；
4. 初始化链：`Application.onCreate()` 通常设置 HTTP client、baseUrl、DI 容器。

**调用链追踪**（A）：`onCreate → View 装配 → click 监听 → ViewModel/Presenter → Repository → ApiService → HTTP`；Dagger/Hilt 找 `@Module` 看接口绑定。混淆时用**字符串字面量与库 API 作锚点**——Retrofit 注解与 URL 不会被混淆。

**REA 的 Android 工具族**（B）：`inspect_android_package`（身份/manifest/覆盖）→ `search_android_classes` → `inspect_android_class` → `inspect_android_method`（同名重载必须显式 `overload_index`，从类清单取，不要猜）→ `trace_android_references`；JNI 用 `inspect_android_jni_bindings`；R8/ProGuard 构建可传 `mapping_path` 做符号归一（mapped/ambiguous/unmapped）。**这些调用各自带 APK 路径与显式选择器，不需要先开 native 会话**（B）。

**API 文档化模板**（A，直接可用）：

```markdown
### `POST /v1/login`
- Source: `com.example.api.ApiService` (ApiService.java:42)
- Base URL: `https://api.example.com/v1`
- Path/Query: `—` / `device_id` (String)
- Headers: `Authorization: Bearer <token>`
- Body: `{ "email": "string", "password": "string" }`
- Response: `ApiResponse<User>`
- Called from: LoginActivity → LoginViewModel → UserRepository → ApiService
```

### 3.4 Native 层（ELF / Mach-O / PE / SO）

**标准序列**（B）：

```
open_binary(path)
  → binary_overview                     # 段与规模，判断"值不值得深挖"
  → search_procedures / search_strings  # 定位候选
  → analyze_function(默认 summary)      # 拿 identity + facet 计数
  → inspect_analysis_view{facet:"pseudocode"|"assembly"}   # 按需分页读
  → xrefs / procedure_callers / get_call_graph             # 关系
  → close_binary
```

**A 的补充判据**（A）：先跑 `survey_binary` 之类的规模画像——如果输出是"少数超大函数（>10 KB）"而不是"大量小函数"，说明被混淆（控制流平坦化），伪代码不可读，直接转动态（见 4.3）；如果字符串全加密，静态搜不到任何线索，也转动态抓运行时解密。

**符号恢复**（A，可操作）：

| 线索 | 具体判据 |
|---|---|
| 魔数 | MD5 `0x67452301/0xEFCDAB89/0x98BADCFE/0x10325476`；CRC32 `0xEDB88320`；AES S-Box `63 7C 77 7B`；Zlib `0x78 0x9C`；Base64 字母表 |
| 成对调用 | `malloc/free`、`lock/unlock`（同一锁对象）、`open/close`（path+flags → handle）、`pthread_create/join` |
| 参数形态 | `socket(2,1,0)`、`connect(fd,&addr,16)`、`memcpy(dst,src,n)`、`memset(ptr,0,0x100)`、`strcmp(...)==0` |
| 返回值 | `-1` 错误（fd/socket）、`NULL` 失败（分配）、`0` 成功、`strlen` 结果直接传给 `memcpy` |
| 上下文 | caller 若有符号，据其用途反推；递归上溯到最近的有符号函数 |

输出必须带**置信度**（High/Medium/Low）与理由，不得只给一个名字（A）。

**结构体恢复**（A）：收集所有 `*(a1 + 0xNN)` / `*(_DWORD *)(a1+8)` / `*(a1 + 8*i)` / `*(*a1 + 0x10)` 访问，记录 offset/size/读写/类型；再看 caller 传参（`&v2`、`malloc(0x40)`）与 callee 的嵌套传递（`another_func(a1+0x20)`）；聚合排序后 `size = max(offset) + last_field_size`。典型模式：offset 0 是函数指针表 → vtable；`next/prev` → 链表；自增自减字段 → refcount。

**去混淆与去虚化**（A）：

| 混淆 | 识别 | 还原路径 | 现实预期 |
|---|---|---|---|
| OLLVM 平坦化 | `while(1){switch(state)}` + 分发器 | D-810（IDA 插件，首选）/ `deflat.py`（angr）/ Triton-Miasm | 单函数可还原，量大成本高 |
| OLLVM BCF | 永真/永假谓词，成片死代码 | 常量折叠 + 剪枝 | 通常可清理 |
| OLLVM Sub | `a+b` 变成位运算串 | 模式匹配回代 | 可批量 |
| VMP | 取字节码 → 跳转表 → handler 循环 | dump 字节码 → 逐 handler 提语义 → 建 opcode 映射 → 写转换脚本 | **商用 VMP 完整还原极难，多数只还原关键片段** |

> **【裁决】"还原"还是"绕过"**：A 的 `VMP虚拟化还原` 自己给出结论——"很多时候更划算的是绕过而非还原：hook VM 的输入输出边界拿明文结果"。这与 B 的证据化路线一致（B 定位为观测与取证，不承诺还原保护逻辑）。**采用"边界优先"策略**：先确定 VM/校验的输入输出契约，再决定是否值得进内部。

**符号执行**（A）：Angr 通用首选，Miasm 适合反混淆重写，Triton 适合单函数精确分析。模板：

```python
proj  = angr.Project("libtarget.so", auto_load_libs=False)
arg   = claripy.BVS("arg", 8*16)
state = proj.factory.call_state(0x1234, arg)
simgr = proj.factory.simulation_manager(state)
simgr.explore(find=0xAABB, avoid=0xCCDD)
print(simgr.found[0].solver.eval(arg, cast_to=bytes))
```

路径爆炸的四条对策：`avoid` 剪枝、缩小符号化范围（只符号化关键输入）、从目标函数中间 `blank_state(addr=...)` 起、`proj.hook` 用 SimProcedure 替换库函数。**工具跑在 PC，不在设备上**（A）。

**Unicorn 片段模拟**（A）五原则：①按 raw 字节映射，不解析 ELF 头（只在代码引用固定段地址时才最小解析）②先识别外部依赖（libc/JNI/syscall）并 hook 模拟 ③大量使用回调 ④迭代修复：崩了读回调信息定位（取指未映射→补代码页；读写未映射→补数据段；命中 import stub→加模拟；死循环→加计数阈值）⑤追踪最小化（块级优于指令级）。JNI 模拟做法：在 UC 内存里伪造 `JNIEnv` 函数表，每个表项写一个 `RET` stub，再 hook stub 地址。

### 3.5 其他目标类型的静态要点

| 目标 | 工具序列 | 必须写进结论的边界 | 来源 |
|---|---|---|---|
| .NET | `inspect_managed_artifact` → `inspect_managed_members(type_names:[...])` → `project_managed_application_graph` | execution-free；metadata token 是 build-local（绑 SHA-256+MVID）；NativeAOT 走 native 路线，不声称恢复 C# 源码 | B |
| Go | `inspect_go_binary` | 缺 build info 不证明不是 Go；静态字符串不含内联到栈/立即数的字面量 | B |
| Rust | `inspect_rust_binary` | 缺 `.dep-v0` 只是该表缺席；rustc commit 由路径推断 | B |
| Electron/JS | `analyze_javascript_application` → `inspect_analysis_view{kind:"javascript"}` → `trace_application_feature` | 静态图不证明运行时加载；`source_paths:[]` 非法；模块序号/压缩名不是稳定身份 | B |
| WASM | `inspect_wasm_artifact`（WABT 1.0.42） | WAT 是反汇编形态，不是原始源码 | B |
| EVM | `inspect_evm_interface(encoding:"raw"|"hex")` | selector/参数/mutability 都是 inferred candidates | B |
| 固件 | `inspect_firmware_regions` → `extract_firmware` → `open_binary` | 不执行提取出的代码；decompressed offset 不是原文件地址；保留 `extraction_gaps` | B |
| PCAP | `inspect_packet_fields` → `inspect_packet_capture` / `inspect_pcap_capture` | 文件分析不做 live capture；page 穷尽不证明网络完整 | B |
| SQLite | `inspect_sqlite_database` | 只读快照含 WAL 的 SHA-256；不执行任意 SQL；行序未定义 | B |
| Apple bundle | `open_bundle_resources` / `open_binary` → `inspect_macho` / `inspect_signature` | 资源会话无 executable digest；签名报存在不报有效 | B |
| DOS-COM | `open_binary(format:"dos-com")` | entry 寄存器上下文是 REA 施加的，不覆盖 PSP/运行时 | B |

### 3.6 静态结论的三条硬边界（B）

1. **静态分析永不等于观测到执行**——不得用"会调用/会加载/会生效"这类措辞描述静态发现。
2. **`null` ≠ 空**——pseudocode 的 `null` 与空文本不同；`null` count 表示 provider 未记录或声明不可用。
3. **缺席 ≠ 从未存在**——缺 `.eh_frame`、import directory、note table、`.dep-v0`，都只是"该表在本次观测中缺席"。

---

## 4. 动态分析与运行时观测

> **本章结论**：动态分析是**补证手段**，不是默认起点。上动态的三个正当理由：参数在运行时才拼装、逻辑在 native 且被加密、需要"值"而非"代码路径"。动态结论必须带锚点（模块基址、函数地址、脚本哈希、设备与版本），否则不可复核（A 的做法缺这一层，B 的证据模型要求补上）。

### 4.1 何时上动态（合并 A/B 的判据）

| 触发条件 | 说明 | 来源 |
|---|---|---|
| 请求参数间接拼装 | 静态无法还原最终出站请求 | A |
| Java 调 native 做签名/加密 | 关键算法不在 DEX 里 | A |
| 自定义网络栈 | 静态搜不到最终请求 | A |
| 需要运行时值（key/token/明文） | 静态只能给代码，给不了值 | A |
| 静态被混淆阻断 | 平坦化使伪代码不可读、字符串全加密 | A |
| 静态证据不足且宿主具备运行时能力 | B 的第五条：**仅当静态无法回答且宿主运行时/OS 权限具备** | B |

### 4.2 设备与 Frida 基线

```bash
adb devices -l                                   # 确认 serial 与 transport
adb shell getprop ro.product.cpu.abi             # 选 frida-server 架构
adb push frida-server-<ver>-android-arm64 /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
adb shell "/data/local/tmp/frida-server &"
frida-ps -U                                      # 连通性验证
```

铁律（A）：
- **frida-server 与 host `frida`/`frida-tools` 必须同主版本**，不匹配表现为连接失败或脚本静默不生效。
- 现代 CLI **没有 `--no-pause`**：`frida -U -f <pkg> -l hook.js` 会在脚本加载完成后自动恢复进程。A 的 `Android动态分析` 仍写 `--no-pause`，属过时用法，**以 `Frida逆向` 的现代写法为准**（A 内部冲突，取后者）。

### 4.3 hook 点选择：先时机，后位置

**时机**（A，最有价值的一节）：不要假设目标 `.so` 已加载。

```
1) hook android_dlopen_ext（Android 优先）或 dlopen
   → 在 onLeave 里装目标 hook（此时构造器已跑完）
2) 若模块已在：Process.findModuleByName 立即检查
3) 轮询仅作兜底（100 ms），并按 module.base 去重（不是按路径）
```

**禁止盲目 hook 初始化链**（`.init`、`.init_array`、constructors、`JNI_OnLoad`）的理由：这些点常做一次性设置；坏 hook 会在真实逻辑之前崩进程；早期 hook 改变时序，会掩盖你要研究的行为；构造器常扇出到大量无关 helper。若确实需要早期观测，正确做法是**先 hook 构造器分发器**（`call_constructors`、`call_array`、linker 侧遍历器、app 侧包装函数），记录构造器序列，定位到具体那一个，再只 patch 它（A）。使用前必须确认该平台/linker 暴露这些函数且有符号或反汇编证据；它们可能不导出，需要符号恢复。

**位置**（A）：优先 hook **最接近最终出站请求**的对象（request builder / interceptor / callback），而不是底层 socket；先拿到 URL/headers/body 与 sign 的输入输出，再决定是否需要绕 pinning 或进 native。

### 4.4 Java 层 hook 配方

```javascript
Java.perform(function () {
  var Cipher = Java.use('javax.crypto.Cipher');
  Cipher.doFinal.overload('[B').implementation = function (input) {
    var out = this.doFinal(input);
    console.log('[Cipher] algo=' + this.getAlgorithm());
    console.log('  in =' + bytesToHex(input) + '\n  out=' + bytesToHex(out));
    return out;
  };
});
```

常用观测面：`javax.crypto.Cipher.doFinal`、`java.security.MessageDigest.digest`、`javax.crypto.Mac.doFinal`、`okhttp3.Request.url`、`java.net.URL.openConnection`、`android.app.ApplicationPackageManager.getPackageInfo`（签名校验）、`java.io.File.exists`（root 检测）。

高层工具（A）：`objection --gadget <pkg> explore` 提供 `android hooking list activities|services|receivers|classes`、`watch class_method <cls>.<m> --dump-args --dump-return`、`android keystore list|dump`、`android heap search instances`、`memory search "password" --string`。

### 4.5 Native 观测与 syscall 层

| 手段 | 适用 | 注意 | 来源 |
|---|---|---|---|
| `Interceptor.attach(Module.findExportByName(...))` | 已导出的 native 函数 | 只对导出有效；内部函数需 `base.add(offset)` | A |
| Frida `Stalker` 过滤 `svc` | 反调试/检测走内联系统调用 | 开销大，限定范围 | A |
| `ptrace(PTRACE_SYSCALL)` | 逐 syscall 读寄存器 | 与反调试互相干扰 | A |
| kprobe / KernelSU 模块 | 应用层拦不住时 | 需内核环境，影响面大 | A |
| REA `observe_native_calls`（LLDB） | macOS 侧托管启动并记录函数入口 | 会真实运行目标；有副作用 | B |
| REA `capture_process_scenario` | 记录终端/文件/网络行为 | **不是安全沙箱**；超时收尾用 `finalization_ms` | B |
| REA `start_frida_session` | 持久 Frida 会话（spawn 后暂停，需 `resume`） | 关闭会话只卸载脚本，不杀目标 | B |

**SVC 速查**（A）：arm64 上 `svc #0`，syscall 号在 `x8`，参数 `x0`–`x5`，返回 `x0`。常见号：56 `openat`（读 `/proc/self/maps`、`/system/bin/su`、`/proc/net/tcp`）、63 `read`、79 `newfstatat`、260 `wait4`、117 `ptrace`、129 `kill(0)`。知道它在读什么，才知道该在哪里伪造返回值。

### 4.6 抓包与证书绑定

| 场景 | 做法 | 来源 |
|---|---|---|
| 普通 HTTPS | Charles / Fiddler / mitmproxy / Reqable + 安装系统证书 | A |
| 有 SSL Pinning | hook `okhttp3.CertificatePinner.check`、`X509TrustManager`；或改 `network_security_config` 信任用户证书（需重打包） | A |
| 非 HTTP / 自定义协议 | `tcpdump -i any -w /sdcard/capture.pcap -G 30 -W 1`，回传后 Wireshark 分析 | A |
| Flutter | **不走系统代理与系统证书**：reFlutter 重打包 patch `libflutter.so`，或 hook `ssl_client_socket`/`SSL_CTX_set_custom_verify`，或 iptables 透明转发 | A |
| WebView / H5 | 走系统代理，设代理+证书即可 | A |
| 浏览器 / Electron | REA CDP：`list_browser_targets` → `inspect_web_page` / `inspect_web_session` / `capture_browser_scenario` | B |

> **REA 侧的两个坑**（B）：①默认捕获 scope 只有页面当前 origin，**SPA 的 API 常在另一个 origin**——必须把 API origin 放进 `allowed_origins` 并读 `completeness.excluded`，否则"没看到该 API"是伪结论；②被动捕获**不含**原始 header 集合、凭据 header 值、storage 值、原始 WS/JSON body。

### 4.7 运行时结论的锚点（补 A 的短板）

A 的动态技能普遍只要求"打印出来看看"。要让结论可复核，每条运行时发现至少要带：

- 设备标识与系统版本、目标包名与版本号、APK/IPA 的 SHA-256；
- 模块名 + 基址 + 函数偏移（或导出名）；脚本文件与其哈希；
- 观测时间与触发路径（点了什么、走到哪）；
- 该值是**观测**还是**推断**（例如"hook 到 doFinal 的输入"是观测；"这就是最终签名串"可能仍是推断）。

（待补充：A 未提供统一的运行时证据模板；上述字段为本工具书按 B 的证据模型补齐的约定。）

### 4.8 AgentEnv：把一次录制变成可重放环境（B）

适用：需要一个 web 应用的 AgentEnv bundle——其 MCP 工具从"一次录制观察到的状态"作答，并只服务该录制确认过的写操作。

```
capture_browser_scenario（一次录完整会话）
  → inspect_analysis_view {kind:"environment-coverage"}   # 看会服务哪些读/写
  → 按 hint 补录（≤2 次，且只为 recording gap）
  → export_environment_bundle {output_directory, name?}    # 目录必须不存在、父目录存在
  → agent-env run <folder>
```

红线（B）：只在用户声明"可丢弃或为本用途 seed 过"的实例上录（每个写步骤都会 create/edit/delete 数据，未声明先问；REA 不启动、不 seed、不 reset 应用）；凭据只来自用户指定的环境变量（`{secret_id, environment_variable}`，且该变量必须在 REA MCP server 启动的环境中），**不要在聊天里要密码**；bundle 会带上录到的响应与本地路径，**不要自行发布或分享**。写工具只有在"后续录制到的读确认了它的效果、且没有读与之矛盾"时才 served，否则 withheld 并给出 reason（`no-state-target`、`no-observation`、`unconfirmed`、`incomplete-entities`、`unexplained-change`、`no-call`、`side-effect`、`contradicted`、`body-unusable`）；`side-effect` 与 `contradicted` 直接停，不再补录。

---

## 5. 加壳、脱壳、绕过与补丁

> **本章结论**：加固只改变"入口"，不改变"目标"。先判型（哪一代、哪一类），再决定投入：**一代壳脱壳即可，二代壳要主动调用，VMP 只做关键片段或边界绕过**。补丁永远是最后一步，且必须可回滚。

### 5.1 壳识别与分级

| 加固 | so 特征 | assets/类名特征 | 分级 |
|---|---|---|---|
| 360 加固 | `libjiagu.so`、`libjiagu_art.so`、`libjiagu_x86.so` | `assets/libjiagu*`、`com.stub.StubApp` | 一代（部分二代） |
| 梆梆 | `libDexHelper.so`、`libDexHelper-x86.so`、`libsecexe.so`、`libsecmain.so`、`libSecShell*.so` | `assets/bangcleplugin/`、`bangcleclasses.jar`、`com.secneo.apkwrapper.ApplicationWrapper` | 一代/二代 |
| 腾讯乐固（御安全） | `libshellx-super.2019.so`、`libtup.so`、`libexec.so`、`libtprt.so` | `com.tencent.StubShell.*` | 一代/二代 |
| 网易易盾 | `libnesec.so` | `com.netease.nis.wrapper.*` | 一代/二代 |
| 爱加密 | `libexecmain.so` | `ijiami.dat`、`ijiami.ajm`、`assets/ijm_lib/`、`s.h.e.l.l.*` | 一代/二代 |
| 通付盾 | `libapp-*.so` + `libtosprotection`、`libtongfudun.so`、`libegis.so` | — | 一代 |
| 百度 | `libbaiduprotect.so` | `baiduprotect1.jar`、`com.baidu.protect.*` | 一代 |
| 阿里聚安全 | `libzuma.so`（旧 `libmobisec.so`） | — | 一代 |
| DexProtector | `libDexProtector*` | — | 二代/VMP |
| AppSealing | `libapssec.so` | `assets/appsealing` | 二代 |
| 娜迦（VMP） | `libchaosvmp.so`、`libddog.so`、`libnagain*` | — | VMP |
| 顶像 / 几维 / 网秦 / Kiro | `libx3g.so` / `libkwscmm.so`、`libkwsgmain.so` / `libnqshield.so` / `libkiroro.so` | — | 一代 |

判型纪律（A）：**多壳共存**（厂商套壳分发）会同时命中多行，按 **so 是否存在**优先，而不是按 assets 字符串。

### 5.2 三条脱壳路线

| 路线 | 手段 | 适用 | 局限 |
|---|---|---|---|
| A 通用脱壳机 | `frida -U -f <pkg> -l frida-dexdump.js`；反射大师、MT 脱壳插件；BlackDex / FullDump（免 root） | 一代整体加密 | 二代方法抽取拿不到方法体 |
| B 内存 dump | hook `DexFile` / `openDexFile` / `defineClass`；或扫 `dex\n035` magic | 需要原始 DEX 整体 | dump 出的 header 常被抹，需修复 |
| C 主动调用 | FART / Youpk / Zhenghun（定制 ROM 或 Xposed 主动调用） | 二代方法抽取 | 工程量大，需特定设备/ROM |

**单工具实操（A）**：

```bash
adb push panda-dex-dumper /data/local/tmp/ && adb shell chmod +x /data/local/tmp/panda-dex-dumper
adb shell "cd /data/local/tmp && ./panda-dex-dumper -p $(adb shell pidof <pkg>)"
adb pull /data/local/tmp/panda/ ./
adb shell "rm -rf /data/local/tmp/panda /data/local/tmp/panda-dex-dumper"
```

要点：走 `ptrace` 必须 root；**必须等壳把 DEX 解到内存后再 dump**（停在启动页 dump 出来是空的，先过启动画面/登录页）；`pidof` 为空时先 `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1`；一次出多个 DEX 属正常，全部 pull；**清理必须做**，残留二进制会被目标 App 的检测扫到（A）。

**dump 后修复**（A）：内存 DEX 常见 `file_size` / `checksum` / `map_off` 异常，不修无法反编译；二代壳 dump 到的常是残壳，需按方法逐个补齐。

### 5.3 非标准运行时的"脱壳"

| 目标 | 判据 | 处理 | 来源 |
|---|---|---|---|
| Unity IL2CPP | `libil2cpp.so` + `global-metadata.dat` | Il2CppDumper 出 `dump.cs`/`script.json`/`il2cpp.h`/`ida_py3.py`，IDA 跑脚本自动命名 | A |
| Unity Mono | `assets/bin/Data/Managed/*.dll` | dnSpy/ILSpy 直接反编译，可改可回编 | A |
| Flutter | `libflutter.so` + `libapp.so` + `assets/flutter_assets/` | Dart AOT 无成熟反编译器：`libapp.so` 进 IDA/Ghidra，用 Doldrums/flutter-header 恢复部分符号，否则纯汇编看关键函数 | A |
| RN / uni-app / Cordova | `index.android.bundle` / `app-service.js` / `assets/www` | 纯 JS 直接格式化读；Hermes 字节码（头 `\x89HBC`）用 hermes-dec/hbctool | A |
| 普通 H5（WebView） | `assets/*.js` + 大量 WebView | js-beautify 格式化；`chrome://inspect` 调试 | A |

**Unity 版本—工具对照**（A）：metadata 头 8 字节 = magic(4)+version(4) 小端，`xxd -l 8 global-metadata.dat` 期望 `af1b b1fa 2700 0000`（version `0x27` = 39）。≤29 用 Perfare/Il2CppDumper；31 部分支持；**39（Unity 6 / 6000.x）必须用 roytu/Il2CppDumper 的 v39 分支（支持 v24–v39）**。Cpp2IL 支持 v39，但 dummy DLL 缺 `[Address]` 属性，适合 C# 源码重建、不适合 IDA 导入。构建 v39 版：

```bash
git clone -b v39 https://github.com/roytu/Il2CppDumper.git
cd Il2CppDumper && DOTNET_ROLL_FORWARD=LatestMajor dotnet build -c Release
DOTNET_ROLL_FORWARD=LatestMajor dotnet run --project Il2CppDumper/Il2CppDumper.csproj \
  -c Release --framework net8.0 -- "$BINARY" "$METADATA" output_dir
```

已知现象：`not a supported version[39]` → 用了原版；exit 137（macOS SIGKILL）→ `codesign -s - <binary>`；exit 134 且 `Cannot read keys` → 非交互下 `Console.ReadKey()` 所致，dump 已成功；空输出 → binary 与 metadata 不是同一次构建。

### 5.4 反检测：先分层定位，再决定手段

| 检测层 | 典型实现 | 对抗手段 | 成本 |
|---|---|---|---|
| Java 层 | `Build.TAGS`、`File.exists(su 路径)`、RootBeer、`getPackageInfo` 签名比对 | Frida hook 返回值；smali 改判断 | 低 |
| Native 层 | `fopen/access/stat` 读 `/proc/self/maps`、`/system/bin/su`、`/proc/net/tcp` | hook libc；改 so 汇编 | 中 |
| 系统服务层 | `PackageManagerService.getInstalledPackages`、`ActivityManagerService.getRunningAppProcesses`、`Settings.Global.getInt` | hook system_server（LSPosed 勾"系统框架"） | 中高 |
| 内核/syscall 层 | 内联 `svc` 直接读文件；`ptrace(PTRACE_TRACEME)` 自保护 | KernelSU/APatch + kprobe；或改 syscall 返回 | 高 |

**完整性校验的四类与顺序**（A）：`.text` CRC 自校验（启动/定时/关键函数前）、DEX CRC（类加载时）、GOT/PLT 校验（敏感调用前）、`/proc/self/maps` 扫描（定时轮询找可写代码段/Frida 痕迹）。判断方法：**单独运行正常，一 hook/patch 就崩 = 存在完整性校验**。处置顺序：①直接改校验逻辑（nop 或 patch 比对跳转）②校验分散则 Frida hook 校验函数统一返回正确值 ③校验读原始文件则改纯内存 hook（Frida inline hook 不改磁盘）④都不行才做双映射/影子页（配合内核层）。**验证要等**：定时校验可能在几分钟后才触发闪退。

优先用现成隐藏方案（Shamiko + LSPosed 排除列表、Zygisk hide），成本最低；现成方案过不了再自写模块（A）。

**对抗实践参照**（这些项目正好覆盖本节的四层）：`Florida`（2.3k，反检测 frida-server，对抗"查进程/扫内存"）、`Hide-My-Applist`（5.7k，模块侧拦截应用列表检测）、`Integrity-Box`（2.8k）、`safetynet-fix`（6.4k，注意 SafetyNet 已被 Play Integrity 取代）、`CorePatch`（3.6k，签名校验）。它们说明本节的分层表不是一次性配置，而是持续对抗——每次目标 App 更新都要重测一遍。

### 5.5 补丁的三种落点

| 落点 | 工具 | 典型改法 | 可回滚性 | 来源 |
|---|---|---|---|---|
| smali（DEX） | apktool / MT 管理器 | 方法体直接 `const/4 v0,0x1; return v0`；`if-eqz`↔`if-nez`；改 `const` 常量 | 需重打包重签 | A |
| SO（汇编） | SOMCP `so_open→analyze_functions→edit_asm→build`；IDA + keystone | `mov w0,#1; ret`；`nop` 掉 `b.eq/b.ne/cbz/cbnz`；反转条件；ret 前改返回值寄存器 | 需重打包重签 | A |
| 运行时（内存） | Frida | `Interceptor.attach(...).onLeave` 改 `retval`；`implementation` 直接返回 | 重启即失效，最安全 | A |

**IDA 侧的最小补丁纪律**（A，值得照抄）：读反汇编+伪代码 → `get_instruction_info` 取精确字节长度 → **先读并打印原字节做备份** → 规划最小补丁（新指令不得超出原字节边界，短了必须用 `NOP`(0x90) 填充，且校验分支目标与相对偏移仍有效）→ `ida_bytes.patch_bytes` 或 keystone 汇编 → `redecompile_function` 验证 → 失败用原字节回滚 → 给补丁处加注释。清理混淆优先 `nop_microcode`（只影响 Hex-Rays IR，不动字节、不破坏对齐）。补丁默认只作用于 IDB，落盘需显式 `File → Produce file → Create patched file`。

**回编常见错误**（A）：资源报错 → `apktool b --use-aapt2` 或 `-r` 跳过资源；寄存器不足 → 调 `.locals`/`.registers`；单方法超 64K 指令 → 拆分或改 hook 方案；multidex → 确认改的是 `classes2/3.dex` 而不是只改 `classes.dex`。

### 5.6 【裁决】脱壳是否是"必经步骤"

- **A 的立场**：加固应用必须先脱壳，否则 jadx 看到的只是壳代码；`Android脱壳`、`AI逆向工作流` 都把"识别壳→脱壳"放在阶段 1。
- **B 的立场**：REA 的 Android 路线是**包/类/方法/资源的静态观测 + 运行时补证**，工具面里没有任何商用壳脱壳能力；它明确 APK 从不启动、不需要模拟器，也不对加固做特别承诺。
- **裁决**：**不把"脱壳"写成所有 Android 任务的前置条件**，改成条件分支：
  1. 先做**壳识别**（5.1）。无壳 → 直接走 3.3。
  2. 有壳且只需**接口/协议/配置**层面结论 → 先用运行时观测（hook 最接近目标的点）+ 资源解码，可能完全不需要脱壳。
  3. 有壳且必须读**被加密的方法体** → 按 5.2 脱壳；脱壳属 A 的领域能力，REA 不覆盖，产物再回到 REA/jadx 做静态分析。
- **理由**：REA 的定位是"证据化观测"，不是"破解保护"；把脱壳写成通则会让无壳目标浪费数小时，也会把 REA 的能力边界说错。冲突已在 9.5 登记（编号 C-02）。

---

## 6. Android 模块开发（Xposed / Vector / libxposed）

> **本章结论**：现代 libxposed（Vector）模块与旧式 Xposed 模块是**两套互不兼容的入口规范**。本章以 C 为准：`META-INF/xposed/module.prop` + `java_init.list`、`minApiVersion=101` / `targetApiVersion=101`、`staticScope=false`、`compileOnly` 桩、`Application.attach(Context)` 时机、Toast + logcat 双证据、Vector CLI 仅 `Version Code >= 3043` 才自动化。

### 6.1 两代规范的差异（一眼判断该用哪套）

| 维度 | 旧式 Xposed（A） | 现代 libxposed / Vector（C） |
|---|---|---|
| 入口声明 | `AndroidManifest.xml` 三个 `meta-data`（`xposedmodule=true`、`xposeddescription`、`xposedminversion=82`）+ `assets/xposed_init` 一行全限定类名 | `META-INF/xposed/module.prop` + `META-INF/xposed/java_init.list` |
| 版本字段 | `xposedminversion=82` | `minApiVersion=101`、`targetApiVersion=101`、`staticScope=false` |
| 依赖 | `compileOnly "de.robv.android.xposed:api:82"` | `compileOnly` 的 `io.github.libxposed.*` 桩（**不得打进 APK**） |
| 入口接口 | `IXposedHookLoadPackage.handleLoadPackage` | 现代入口类 + `Application.attach(Context)` |
| hook API | `XposedHelpers.findAndHookMethod`、`XC_MethodHook`、`XC_MethodReplacement` | libxposed 现代 API（细节见 `references/vector-api-notes.md`） |
| 作用域 | 管理器 UI 勾选，**无可提交的声明文件** | 由 Vector CLI/管理器配置，可脚本化（有版本门禁） |
| 验证证据 | `XposedBridge.log` 看日志 | **必须**有用户可见 Toast + 三条 logcat |

> **【裁决】模块规范以 C 为准**（冲突编号 C-03）。理由：A 的 `Xposed模块构建` 是 legacy API 82 的写法，且原文把 `assets/` 放在工程根（正确位置应是 `app/src/main/assets/`），按原文构建会**静默不生效**；C 是针对当前 Vector/libxposed 的可运行规范，并给出构建后自检命令。A 的内容保留为"维护旧模块时的参考"，不作为新工程模板。

**生态现状**（2026-11-14 star 快照）：LSPosed 25.5k、VirtualXposed 16.1k、**Vector 13.2k**、原版 `rovo89/Xposed` 7.7k 且已停更。这颗星数分布本身就是 C-03 裁决的旁证：新工程应当按 modern 规范写，legacy 只用于读老模块。**可直接读代码学的参考实现**：BiliRoaming（11.5k，现代模块的标准工程结构）、QAuxiliary（5.8k，多版本/多客户端适配）、HyperCeiler（5.7k，系统级 hook 的写法）、CorePatch（3.6k，签名校验绕过的成熟实现，对应 5.4）。完整索引见 [9.8](#98-社区项目索引与整合建议)。

### 6.2 工程结构（现代）

```
app/src/main/
├── AndroidManifest.xml
├── java/<pkg>/MainHook.java              # 入口类，含 Application.attach hook
├── assets/
│   └── xposed_init                        # 仅 legacy 兜底；targetApiVersion>=101 时 Vector 优先 modern
└── resources/META-INF/xposed/
    ├── module.prop                        # minApiVersion=101 / targetApiVersion=101 / staticScope=false
    └── java_init.list                     # 一行：入口类全限定名
```

`module.prop` 最小内容（C）：

```properties
minApiVersion=101
targetApiVersion=101
staticScope=false
```

打包后自检（**必做**，C）：

```bash
unzip -p app/build/outputs/apk/debug/app-debug.apk META-INF/xposed/module.prop
unzip -p app/build/outputs/apk/debug/app-debug.apk META-INF/xposed/java_init.list
unzip -l app/build/outputs/apk/debug/app-debug.apk | rg 'io/github/libxposed|META-INF/xposed|xposed_init'
```

第三条命令用来确认：**`io/github/libxposed/*` 不应出现在 APK 里**（出现即为桩被打包，运行期会类冲突）。

### 6.3 入口与时序（最容易做错的一步）

规则（C）：
1. 现代入口 hook `Application.attach(Context)`——这是**拿到目标进程 ClassLoader 的最早可靠时机**。
2. 业务 hook **必须**在 `Application.attach(Context)` 完成后安装，并使用 **attach 传入的 Context 的 ClassLoader**。
3. **不要**在 `onPackageLoaded` 阶段用模块自身的 loader 去解析目标类——那时目标类还没被加载，必然 `ClassNotFoundException`。
4. 主线程弹 Toast（用户可见证明），日志 tag 固定 `VectorToastModule`。

Toast 文案（C 指定）：

```
Vector 注入成功: <target-package>
```

> **【裁决】Toast 是否可有可无**：C 要求"除用户明确要求无 Toast 外必须保留"，A 的旧式模块只用 `XposedBridge.log`。**取 C**：Toast 是唯一不依赖 adb 的用户可见证据，尤其在自动化被版本门禁拦下、需要用户手动确认时不可替代。

### 6.4 构建前置：三个"不要假设"

**不要假设全局 gradle**（C）：模板自带 Gradle 8.7 wrapper，顺序为

```bash
./build_debug.sh                     # 首选
./gradlew :app:assembleDebug         # 次选
GRADLEW=/path/to/gradlew ./build_debug.sh
gradle :app:assembleDebug            # 最后才回退全局
```

**不要假设当前 java 可用**（C）：JDK 探测顺序 `JDK_HOME` → `JAVA_HOME` → `/usr/libexec/java_home -v 17` → Homebrew `openjdk@17`/`temurin@17` → `/Library/Java/JavaVirtualMachines/*/Contents/Home` → PATH 上的 `java`（必须是 17）。调用时显式传：

```bash
./gradlew -Dorg.gradle.java.home="$JDK17_HOME" :app:assembleDebug
```

**不要假设 Android SDK 可被发现**（C）：探测 `ANDROID_HOME` → `ANDROID_SDK_ROOT` → `local.properties` 的 `sdk.dir` → `$HOME/Library/Android/sdk` → `$HOME/Android/Sdk` → `$HOME/Android/sdk`，命中后写回 `local.properties`。

工程纪律（C）：**不得提交 `local.properties`**、不得硬编码 `/Users/<name>`、不得依赖他人的外部 wrapper。模板分发前跑 `./preflight.sh` 与 `./build_debug.sh`；设备相关检查用 `./preflight.sh --device`。

### 6.5 安装与启用（含版本门禁）

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell su -c "/data/adb/lspd/cli status --json"      # 先探测 Vector 版本
```

**安全门（C，硬规则）**：解析输出中的 `Version Code`，**仅 `>= 3043` 才允许自动执行 `modules enable` / `scope add|set`**；低于该版本：安装 APK 但不改动模块状态，明确提示用户到管理器里手动启用并配置作用域。

| 命令 | 语义 |
|---|---|
| `cli status` / `cli status --json` | 框架状态与版本 |
| `cli modules ls\|enable\|disable` | 模块列表与启停 |
| `cli scope ls\|add\|set\|rm` | 作用域查询/追加/整体替换/删除 |
| `cli log cat` | 加载失败时看框架侧日志 |

注意：`scope add` 是**追加**，`scope set` 是**整体替换**；除用户明确要求外**不要 kill/restart lspd**（C）。

### 6.6 验证序列（照抄即可）

```bash
adb shell su -c "/data/adb/lspd/cli status --json"
adb shell su -c "/data/adb/lspd/cli modules enable <MODULE_PKG>"
adb shell su -c "/data/adb/lspd/cli scope add <MODULE_PKG> <TARGET_PKG>/0"
adb logcat -c
adb shell am force-stop <TARGET_PKG>
adb shell monkey -p <TARGET_PKG> 1
sleep 4
adb logcat -d | rg 'VectorToastModule|VectorModuleManager|VectorLifecycle|<MODULE_PKG>|Failed to instantiate|Class does not extend'
```

期望看到三行（C）：

```
VectorModuleManager: Loaded module <MODULE_PKG> successfully.
VectorToastModule: hooked Application.attach for package=<TARGET_PKG>
VectorToastModule: injected package=<TARGET_PKG> process=<TARGET_PROCESS>
```

同时用户应看到 Toast `Vector 注入成功: <TARGET_PKG>`。若模块没加载，改看框架日志：`adb shell su -c "/data/adb/lspd/cli log cat"`。

### 6.7 免 root 的三条替代路径（A）

| 方案 | 命令/要点 | 适用 |
|---|---|---|
| LSPatch | `java -jar lspatch.jar 目标.apk -m 模块.apk -l 2`（`-l 2` = 本地集成模块；另有 manager 模式） | 已有模块 APK，设备无 root |
| Frida Gadget | `frida-gadget.so` 放 `lib/<abi>/`；入口 smali 或最早加载点 `System.loadLibrary("gadget")`；配 `libgadget.config.so`；重签 | 要跑复杂 Frida 脚本 |
| SimpleHook | 应用内配置 hook 规则（改返回值/参数），零代码 | 只改一两个返回值 |

（待补充：C 只覆盖 LSPosed/Vector 路线，未涉及 LSPatch 与 Vector 的兼容性；A 未说明 LSPatch 对 `META-INF/xposed/*` 现代入口的支持情况。）

### 6.8 模块开发常见失败对照表

| 现象 | 最可能原因 | 处置 |
|---|---|---|
| 装上了但完全没反应 | `module.prop`/`java_init.list` 路径错（放到了工程根或 `assets/`），或 `targetApiVersion=100` 未按 modern 加载 | 用 6.2 的 `unzip -p` 逐条核对 |
| `ClassNotFoundException`（目标类） | 在 `onPackageLoaded` 用模块 loader 解析目标类 | 改到 `Application.attach` 之后，用传入 Context 的 ClassLoader |
| `Failed to instantiate` / `Class does not extend` | 入口类未实现要求的接口/父类，或依赖桩版本不匹配 | 看 `cli log cat`；核对桩版本 |
| 类冲突 / 启动即崩 | `io.github.libxposed.*` 被打进 APK | `unzip -l | rg io/github/libxposed` 必须为空 |
| 手动能启用、脚本改不动 | Vector `Version Code < 3043` | 停自动化，让用户手动启用与配 scope |
| 作用域生效但业务没跑 | hook 装太早或类未加载；或作用域包名写错（应为 `包名/用户id`，如 `/0`） | 换 hook 点；核对 `scope ls` |

（待补充：C 未给出多进程应用（`:remote` 等）的作用域写法与 `process=` 过滤建议；A 也未覆盖。）

---

## 7. 证据、比较与交付

> **本章结论**：证据不是"截图+结论"，而是一条**可复核的记录**：它带稳定 ID、带权威度、带限制、带覆盖范围、带仍未解决的未知。REA 把这套模型固化进每个工具的返回值（B）；本章把它抽成与工具无关的写法，供任何来源的分析结论套用。

### 7.1 证据模型（六个字段）

| 字段 | 含义 | 常见错误 |
|---|---|---|
| `evidence_id` | 该证据的稳定锚点（形如 `ev_...`） | 用文件路径当锚点（路径会变，内容会换） |
| `authority` | 证据的权威类型：`shipped-artifact` / `controlled-replay` / `historical-reference` / `external-service` / `analyst-inference` | 把分析者推断写成 `shipped-artifact` |
| `confidence` | `observed` / `derived` / `inferred` | 把 `inferred` 写成 `observed` |
| `limitations` | 本次观测的固有限制 | 省略"provider 不支持该 metadata"这类前提 |
| `coverage` | 覆盖到哪、没覆盖到哪（含 `next_offset`） | 把"这一页看完"说成"全部看完" |
| `residual_unknowns` | 仍未解决的问题清单 | 把未知藏进正文，让读者以为已闭环 |

**引用与分页的两条纪律**（B）：
- 逻辑证据可以用 `{kind:"retained-evidence", evidence_id}` 代替整条记录；解析**不重跑分析**，也**不把不完整变完整**；引用不能跨域替代（native dossier 不能顶替 managed member 观测）。
- summary 视图自身也有 `evidence_id`，但它**只代表这个视图**；要指回完整源必须用 `normalized_result.parent_evidence_id`。

### 7.2 结论的措辞规范

| 事实状态 | 允许的措辞 | 禁止的措辞 |
|---|---|---|
| 静态看到调用 | "代码存在对 X 的调用" / "静态引用显示…" | "会调用 X"、"运行时会执行" |
| 运行时 hook 到 | "在 <设备/版本> 上观测到 X 被调用，参数为…" | "X 一定被调用"（超出观测条件） |
| 由命名/结构推断 | "推断为 vtable（依据：offset 0 为函数指针表）" | "这是 vtable" |
| 未覆盖 | "在本次 source_paths 范围内未出现；不代表不存在" | "不存在" |
| 签名/摘要 | "签名存在且自洽" | "签名有效/可信/正版" |

### 7.3 比较与变更分析

| 工具 | 比什么 | 硬约束 | 来源 |
|---|---|---|---|
| `compare_functions` | 两个**显式** function Evidence | **拒收 `analyze_function` 的 summary**，要传 `parent_evidence_id` 或完整 dossier | B |
| `compare_artifacts` | inventory 的 occurrence path / 内容 / 元数据 / 图关系 | 支持 summary 输入；其他消费方不保证支持 | B |
| `compare_bundles` | canonical bundle 成员 + unknown 历史 | 缺成员只描述 omission，**永不等于行为等价** | B |
| `match_native_functions` | 唯一精确名 + 完整 body bytes | unpaired 不证明新增/删除 | B |
| `find_changed_behavior` | 聚合既有比较 | 静态差异只是候选，不是因果 | B |
| `build_call_path` | 最短直接 callee 路径 | 需同 artifact/provider 完整 dossier；前沿不完整则 absence unknown | B |
| `correlate_static_and_runtime` | 显式 mapping 关联静态与运行时 | 不按名字自动匹配；cochange 不证因果 | B |
| `verify_reconstruction` | 有限 typed specification | pass 只覆盖声明的 claim，**不是全局等价** | B |
| `export_evidence_bundle` | 写完整 canonical 会话 | 目标路径必须可写；导出后仍可 import | B |

**等价结论的前提**：只在**完整、兼容的 page set** 上声明等价或缺失；`source_complete` 与 page 穷尽是两个维度（B）。

### 7.4 未知项登记（把"没搞清"变成资产）

`record_unknown` 的字段（B）：`question`、`severity`、`domain`、`required_authority`（`shipped-artifact` / `controlled-replay` / `historical-reference` / `external-service` / `analyst-inference`）、`required_confidence`、`required_environment`、`recommended_probes`、`relationships`，并附 `supporting_evidence_ids` / `contradicting_evidence_ids`。

使用规则：
- `update_unknown` 必须带当前 `revision`；revision 陈旧要**重读**，不要盲重试。
- `verify_unknown_resolution` 用 live evidence 重新校验；**只有合格的 `observed` 证据**才能把 unknown 标为 resolved。
- 未知项与结论冲突时，保留双方，写清"当前证据倾向哪边、还缺什么"——不要二选一硬下结论。

### 7.5 交付物模板

**一份可交付的逆向报告**至少包含：

1. **目标身份**：文件/包的 SHA-256、版本号、获取渠道、分析日期。
2. **工具与版本**：引擎与 provider、脚本与其哈希、设备与系统版本（动态部分）。
3. **结论清单**：每条一句话 + 证据 ID + 置信度。
4. **关键路径**：调用链图或 API 表（用 3.3 的模板）。
5. **限制与未覆盖**：scope 之外有什么、哪些结论依赖单一证据。
6. **剩余未知**：编号、问题、需要什么才能回答（对应 7.4 的字段）。
7. **可复现步骤**：命令序列，能被第二个人跑出同样结果。

**API 文档表**、**hook 记录表**（hook 点、模块基址+偏移、观测字段、选点理由）、**补丁记录表**（地址、原字节、新字节、验证方式、回滚方法）是三种最常用的子表。

### 7.6 工作区与产物规范

- 原包与派生物分目录：`samples/`（只读）、`work/`（解包与中间产物）、`out/`（交付物）；每步保留回滚点（B 的"keep original and derived artifacts separate"；A 的重打包流程也要求保留原 APK）。
- **证据要落盘再关会话**：REA 的引用只活在当前 MCP 连接的 ledger 里，`close_binary` 不会清掉它，但进程重启会；跨进程交接用 `export_evidence_bundle`，或 `reset_investigation(save_path)` 先 checkpoint（B）。
- **不要发布 AgentEnv bundle**：它包含录到的响应与本地路径，可能触发 `credential-named-members` 警告（B）。

> **【裁决】A 的"原地改样本"工作流**：A 的 smali/so 补丁技能默认直接改样本并重打包重签，全流程没有 SHA-256、只读副本或回滚点要求。**以 B 的产物分离原则为准**：所有改动在 `work/` 的副本上进行，`samples/` 保持只读，补丁前后各记一次哈希（冲突编号 C-05）。

---

## 8. 故障排查与常见问题

> **本章结论**：排障的第一原则是**分清"我的环境"和"对方的能力"**。REA 侧的错误分两类：客户端 deadline 与服务端 provider 预算，补救方式完全不同；A 侧的问题几乎都在"版本不匹配"与"时机不对"。

### 8.1 环境类

| 现象 | 定位 | 处置 | 来源 |
|---|---|---|---|
| `node`/`npx` 找不到或版本不符 | `command -v rea && command -v node && node --version` | 需 `^22.23.4 \|\| ^24.22.1 \|\| >=26.12.1`；不要为修 MCP 注册去装/升 Node | B |
| Gradle 构建失败 | `./gradlew --version` 用的哪个 JDK | 显式 `-Dorg.gradle.java.home=$JDK17_HOME`；不用全局 gradle | C |
| `sdk.dir` 找不到 | `local.properties` 是否存在且正确 | 按 6.4 的探测顺序回填；不要提交该文件 | C |
| `adb devices` 为空 | USB 调试授权、驱动、`adb kill-server` 后重试 | 确认 serial；REA 的 adb 工具都要求显式 `serial` | B/C |
| Frida 连不上 / 脚本不生效 | server 与 host 主版本是否一致 | 换同版本 server；或改用 Gadget 注入 | A |

### 8.2 REA 侧：两种超时不要混

| 现象 | 含义 | 正确动作 |
|---|---|---|
| host 报 `timed out awaiting tools/call`，且**没有 REA 结果** | 客户端 deadline 先到；不证明 REA 完成/取消/释放 | 不重复同一分析；查 session 或 partial Evidence；必要时把 host deadline 调到覆盖 execution+cleanup+delivery（Codex：`mcp_servers.<server>.tool_timeout_sec`，单位秒） |
| REA 返回 `provider_timeout` | 服务端/provider 预算到点 | 按 `remediation.action`；复用它已给的 partial Evidence；先解决报出的 incomplete cleanup |

其他高频错误（B）：

| 错误 | 处置 |
|---|---|
| `cleanup_incomplete` | 重试**那个确切的 cleanup owner**；它确认释放前不要开需要这些资源的新工作；重发原调用不算重试 |
| `resource_constraint` + `retryable: true` | 等当前 admission 结束再在限额内重试；**不要重启 REA 腾槽** |
| `configuration_invalid`（`update_mode:"runtime"`） | `update_analysis_settings {setting, action:"set", value}`，等 work/cleanup 安定后重试同一输入 |
| `configuration_invalid`（`update_mode:"parameter"`） | 改该次调用参数（setter 不接受这个字段） |
| `invalid_request` | 按当前 schema 改完**所有**报告字段，不要原样重发 |
| 大响应被客户端截断 | 用 `parent_evidence_id` 取小页或 `export_evidence_bundle`；不要把 preview 当 canonical JSON |

**Ghidra 首次分析超时**（B）：默认启动预算 330 s（`REA_GHIDRA_STARTUP_TIMEOUT_MS`）；改 `ghidra.startup_timeout_ms` 不需重启，但**已被接受的 startup 保留原预算**；单函数反编译超时改 `ghidra.decompile_timeout_seconds`（`null` 移除该 deadline）。

**doctor 的边界**（B）：`rea doctor` 只查注册与配置，**不能证明当前 agent 的连接已建立**，也不能恢复 live 连接。plugin 安装时 `doctor --client/--skill` 报 `missing` 是 setup-owned 检查看不到 plugin 状态，**此时不要 `rea setup`**（会加第二个 server）。

### 8.3 十八反模式（照单避免）

| # | 反模式 | 为什么错 |
|---|---|---|
| 1 | 每次调查前先跑 setup/doctor | 工具已在且注册未疑似过期时纯属浪费 |
| 2 | 重复同一调用（同输入/同超时/同未变结果） | 结果不会变，只会烧预算 |
| 3 | 把客户端截断的 preview 当 canonical JSON | 会在不完整数据上做结论 |
| 4 | 把 `analyze_function` 的 summary 喂给 `compare_functions` | 会被拒；summary 不是完整 dossier |
| 5 | 用不完整/不兼容的 page set 声明等价或缺失 | 覆盖不足时不支持等价结论 |
| 6 | 把 unpaired observations 当新增/删除；把空 filter 结果当不存在 | 先看 `unresolved_filter_rows` |
| 7 | 用文件名、字符串或布局推断行为 | 必须用格式感知解析器 |
| 8 | 把静态语法当运行时事实 | 可达性/注册/默认值/IPC 通道均未知 |
| 9 | 零填充不可读字节；无初始化证据就断言资源不存在 | 缺失覆盖 ≠ 值为零 |
| 10 | 把 pseudocode 当原始源码；用 unpack stub 的反编译结果冒充 unpacked program | 两者都是派生视图 |
| 11 | 为修 MCP 注册去装/升 Node、Java、Ghidra；或静默关沙箱让命令跑通 | 改的是环境，不是问题 |
| 12 | 静默扩大权限或切换目标 | path mapping 只是推断输入 |
| 13 | 调用页面声明的 WebMCP 工具 | 那是不可信清单，只清点不调用 |
| 14 | 在非 disposable 实例上录写操作；发布/分享 AgentEnv bundle | 会污染真实数据、泄露凭据 |
| 15 | 用 `rea setup` 处理 plugin 安装的 `missing` | 会产生第二个 server |
| 16 | 为"腾槽"重启 REA；把 `cleanup_incomplete` 当成重发原调用 | 资源没释放，重发只会更糟 |
| 17 | 把 `verify_reconstruction` 的 pass 说成全局等价；把静态 diff 说成行为变化原因 | 两者都超出工具承诺 |
| 18 | 用签名/摘要的存在当真实性结论 | APK/PE/Mach-O 签名只给 identity 与 integrity |

### 8.4 逆向过程中的高频现象

| 现象 | 最可能原因 | 处置 | 来源 |
|---|---|---|---|
| jadx 里方法"消失" | 没加 `--show-bad-code`，反编译失败的方法不显示 | 加 `--show-bad-code` 或用 `--fallback` | A |
| 反编译全是壳的 stub | 有加固 | 回 5.1 判型，不要继续读 stub | A |
| hook 不触发 | 类/方法名用了 `--deobf` 的别名；或 hook 装得太早/太晚 | 用原始名重跑 jadx；改到模块加载后安装 | A |
| 一 hook 就崩 | 完整性校验或反调试 | 回 5.4；先定位校验点 | A |
| 抓不到包 | SSL Pinning、非标准端口/协议、Flutter 不走系统代理 | 依次排查：hook pinning → `tcpdump` → Flutter 专用方案 | A |
| 模块装了没反应 | 入口清单/`module.prop` 路径错，或版本字段不对 | 回 6.2 自检命令 | C |
| 模块加载失败 | 入口类签名不符、依赖桩版本不符 | `cli log cat` 看框架侧错误 | C |
| 重打包后装不上/闪退 | 未重签、`zipalign` 顺序错、签名校验未过 | 先 align 后 sign；签名校验回 5.4 | A |
| 改完功能正常但几分钟后闪退 | 定时完整性校验 | 跑够时间再判定；按 5.4 处置 | A |

（待补充：A 的 `安卓渗透测试` 引用的 `01/02/03/05-unified-*.md` 等 SOP 文件在语料目录内不存在，属断链；无法核对其中步骤。）

---

## 9. 附录

### 9.1 加固特征库与判型卡

**扫描顺序**（A）：① 先列 `lib/<abi>/*.so` 与 `assets/` 目录名（最快，且不会被 assets 字符串误导）② 再看 `AndroidManifest.xml` 里的 `android:name`（壳的 Application 类名是强特征）③ 最后用 APKiD 之类规则引擎兜底（规则会滞后于新版壳）。

| 判型结论 | 判定依据 | 后续动作 | 预期成本 |
|---|---|---|---|
| 无壳 | 无壳 so、Application 是业务包名、DEX 可直接反编译出业务类 | 直接 3.3 | 低 |
| 一代（整体加密） | 有壳 so，但内存中 DEX 完整（通用脱壳机可整包 dump） | 5.2 路线 A | 低—中 |
| 二代（方法抽取） | dump 出的 DEX 方法体为 `native` 或空实现（`return null` 桩） | 5.2 路线 C（FART/Youpk 主动调用） | 高 |
| VMP（指令虚拟化） | 关键方法落在 `libchaosvmp.so` 等 VM 里，native 侧只有分发器 | 5.6 策略：边界 hook 取明文，不承诺还原 | 很高 |
| 多壳共存 | 同时命中多厂商 so/assets | 按 **so 是否存在** 取主壳，assets 字符串只作辅证 | 取决主壳 |

**误判处理**：`assets` 里出现厂商字符串不等于在用该壳（可能是 SDK 残留）；`libxxx.so` 存在但未被 `System.loadLibrary` 引用同理。判型结论要能回答"**壳的入口在哪、它加载了什么**"，而不是"包里出现了什么字符串"（B 的格式感知原则在此同样适用）。

### 9.2 工具—目标矩阵

| 目标类型 | 首选（B：REA） | 备选/补充（A） | 何时必须换路 |
|---|---|---|---|
| Android APK（DEX/资源） | `inspect_android_package` / `search_android_classes` / `inspect_android_method` | jadx（阅读）、apktool（回编）、MT 管理器 MCP（设备侧） | 有加固（5.1） |
| Android 运行时 | `start_adb_app` + `read_adb_logcat` + `inspect_adb_*`；Frida（`start_frida_session`） | Frida + objection、SimpleHook、LSPatch | 反调试/反 Frida（5.4） |
| Native ELF/SO | `open_binary` → `binary_overview` → `analyze_function` | rizin（快速）、IDA（深挖）、Unicorn（片段） | 混淆严重（3.4） |
| PE / .NET | `open_binary` / `inspect_managed_artifact` | IDA、dnSpy | NativeAOT |
| Mach-O / iOS | `open_binary` → `inspect_macho` / `inspect_signature`；`observe_native_calls` | frida-ios-dump（脱壳）、class-dump | 加密的 App Store 包 |
| Electron / JS | `analyze_javascript_application` → `inspect_analysis_view` | `recover_javascript_sources`（Wakaru） | 压缩/ASAR 完整性校验 |
| 浏览器 Web | `list_browser_targets` → `inspect_web_page` / `capture_browser_scenario` | DevTools、mitmproxy | — |
| WASM | `inspect_wasm_artifact`（WABT） | wabt 手工 | — |
| 固件 | `inspect_firmware_regions` → `extract_firmware` | binwalk/unblob 手工 | 非 Linux 宿主 |
| PCAP | `inspect_packet_capture` | tshark/Wireshark 手工 | 需要 live capture |
| SQLite | `inspect_sqlite_database` | sqlite3 CLI | 需要写操作 |
| Unity IL2CPP | `inspect_il2cpp_metadata` | Il2CppDumper + IDA | metadata 头加密 |
| Flutter | `identify_flutter_build` / `inspect_dart_aot` | reFlutter、Doldrums | AOT 符号恢复 |

### 9.3 命令速查

```bash
# --- 环境自检 ---
rea --version && command -v rea && command -v node && node --version
rea doctor --client codex --json
adb devices -l
java -version    # 需 17

# --- APK 静态 ---
jadx --no-res -j 8 app.apk -d out
jadx --show-bad-code --fallback app.apk -d out
apktool d app.apk -o app_src -f
apktool b app_src -o app_new.apk
zipalign -v 4 app_new.apk app_aligned.apk
apksigner sign --ks my.keystore app_aligned.apk
apksigner verify --print-certs app_aligned.apk

# --- native 静态 ---
file libfoo.so && rz-bin -I libfoo.so && rz-bin -s libfoo.so
rz-strings -a libfoo.so | rg 'http|Java_|JNI_OnLoad|RegisterNatives|encrypt|sign'
rizin -qc "aaa; afl; pdf @ sym.JNI_OnLoad; q" libfoo.so

# --- 动态 ---
frida-ps -U
frida -U -f <pkg> -l hook.js
frida -U <pkg> -l hook.js
objection --gadget <pkg> explore
tcpdump -i any -w /sdcard/capture.pcap -G 30 -W 1

# --- 模块（Vector） ---
./preflight.sh --device
./build_debug.sh
unzip -p app/build/outputs/apk/debug/app-debug.apk META-INF/xposed/module.prop
adb shell su -c "/data/adb/lspd/cli status --json"
adb shell su -c "/data/adb/lspd/cli scope add <MODULE_PKG> <TARGET_PKG>/0"
adb logcat -d | rg 'VectorToastModule|VectorModuleManager'

# --- REA 无 MCP 时的兜底（只证明 CLI 可用，不证明 MCP 已配置） ---
npx -y rea-agents@6.9.0 analyze-javascript-application /abs/path/app --json
```

### 9.4 来源覆盖表

#### A：按目录逐一核对（47 个技能目录 + 1 篇全景分析）

| 目录 | 处理 | 落点 |
|---|---|---|
| Android逆向工程 | 全文精华收录（7 Phase、判型四问、.so 五步、交付 6 项） | 3.1–3.4 |
| Jadx反编译 | 收录参数矩阵与 grep 配方；`--deobf` 加注裁决 | 3.3 |
| Smali重打包 | 收录改写模式与回编错误 | 5.5 |
| APK解包工具 | 收录命令与产物结构；修正 zipalign 顺序 | 5.5 / 9.3 |
| Android脱壳 | 收录三路线与分级 | 5.2 |
| 加壳识别 | 特征表合并进 5.1；判型顺序进 9.1 | 5.1 / 9.1 |
| DEX内存脱壳 | 收录 panda-dex-dumper 全流程与清理要求 | 5.2 |
| IDAPro逆向分析 | 收录工具三件与常量表；API 参考列为"查得到就不用背"未收录 | 3.4 |
| IDAPython逆向 | 收录 IDALib headless 与 microcode 阶梯；799 行碎片只留签名 | 3.4 |
| IDA反编译 | **判为单样本实录**，只作"锚点表"示例，不作流程 | 3.4（边界说明） |
| IDA智能补丁 | 全文收录（最小补丁纪律） | 5.5 |
| OLLVM反混淆 | 收录识别/还原四条路；原文第 19 行截断已标注 | 3.4 / 9.6 |
| VMP虚拟化还原 | 收录结构与 6 步，采纳"绕过优先"结论 | 3.4 / 5.6 |
| 静态符号执行 | 收录三引擎选型 + Angr 模板 + 路径爆炸对策 | 3.4 |
| Unicorn调试 | 收录五原则、回调面、架构表 | 3.4 |
| 结构体逆向 | 收录五步法 | 3.4 |
| 符号恢复 | 收录线索表（魔数/成对/参数/返回值） | 3.4 |
| 逆向补丁技术 | 收录三种落点与 Frida 验证 | 5.5 |
| SVC指令追踪 | 收录 syscall 号表与三种观测法 | 4.5 |
| 协议加密分析 | 收录抓包、指纹、签名还原套路 | 4.6 / 3.3 |
| Android动态分析 | 收录 7 步与坑；`--no-pause` 已裁决为过时 | 4.2–4.4 |
| Frida逆向 | 全文核心收录（现代 API、加载时机、禁盲 hook） | 4.3 / 4.4 |
| Frida脚本集 | 与 Frida逆向 重复，未单列 | — |
| 免RootHook | 收录三方案对照 | 6.7 |
| 签名绕过 | 收录三处检测与三级绕过 | 5.4 |
| 内存完整性绕过 | 收录四类校验与处置顺序；截断已标注 | 5.4 / 9.6 |
| 内核系统Hook | 收录四层模型与 system_server 常 hook 点 | 5.4 |
| Unity IL2CPP逆向 | 收录判型、dump.cs 用法、版本—工具对照 | 5.3 |
| Unity3D脱壳 | 与上条合并（同一目标类型） | 5.3 |
| Flutter逆向 | 收录识别三件套、抓包三法、AOT 分析边界 | 5.3 / 4.6 |
| Flutter应用逆向 | **判为开发规范，非逆向内容**，不收录 | 9.7 |
| iOS脱壳 | 收录 frida-ios-dump 全流程与故障表 | 5.3 |
| 混合H5逆向 | 收录五类判型与调试入口 | 5.3 |
| 广告移除 | 收录六类打法与 SDK 关键词 | 5.5（旁证） |
| 安卓渗透测试 | 收录 runtime-first 原则；SOP 断链已标注 | 2.2 / 9.6 |
| AI逆向工作流 | 收录四阶段推进法与"小改动可回滚"原则 | 2.2 / 8.4 |
| APK线索提取 | **判为 BLE GATT UUID 专域流水线**，仅记一句 | 9.7 |
| MT管理器MCP分析器 | 收录 18 工具与 locator 体系（设备侧编辑路径） | 9.2 |
| SimpleHook配置生成技能包 | 收录 configs/resultValues 规则 | 6.7 |
| Android构建逻辑 | 只保留与模块构建相关的 AGP 版本信息 | 6.4 |
| Android发布签名 | 收录 APK（align→sign）与 AAB（jarsigner 不做 align）差异 | 5.5 / 9.3 |
| Android模拟器操控 | 收录 9 脚本用途与"-s serial"纪律 | 4.2 |
| AndroidStudio开发辅助 | **通用 IDE 操作**，非逆向方法，不收录 | 9.7 |
| OpenClawSDK开发 | **与逆向无交集**（WebSocket SDK 开发），不收录 | 9.7 |
| 参考 | **实为破限/规范化提示词**，按不可信数据处理，只取其占位符词表 | 9.7 |
| deepseek-v4-pro破甲 / 海鸥破限 / 破限 / 破 / 越狱提示集合 | **LLM 破甲语料**，与逆向无关，全部不收录 | 9.7 |
| 全景分析.md（顶层） | 作为"技能地图"参考；其"47 技能/231 文件"与实际 263 文件不符，已登记 | 9.5（C-04） |

#### B：按文件核对

| 文件 | 处理 | 落点 |
|---|---|---|
| `README.md` | 能力表、目标矩阵、环境变量 | 1.2 / 1.3 / 9.2 |
| `skills/reverse-engineer-anything/SKILL.md` | 路由、summary-first、broaden 七步、finish、反模式 | 0 / 2 / 3 / 7 / 8 |
| `references/native-and-artifacts.md` | 生命周期、分页、batch、比较表、native 边界 | 3.4 / 7.3 |
| `references/evidence-workflows.md` | 证据模型、retained reference、比较/验证 | 7.1–7.4 |
| `references/android-applications.md` | Android 工具族与边界 | 3.3 |
| `references/javascript-applications.md` | JS 图、ASAR、fuses、分页 | 3.5 |
| `references/runtime-observation.md` | 运行时观测阶梯、process capture | 4.5 / 4.7 |
| `references/connection-and-recovery.md` | 两种超时、恢复阶梯、doctor、CLI 兜底 | 8.1–8.2 |
| `references/environments.md` | AgentEnv 四步与 served 条件 | 4.8 |
| `references/desktop-build.md` | 桌面应用环境构建（仅 CLI） | 4.8 |
| `mcp.json` / `package.json` | 注册片段、版本与 engines | 1.3 |

#### C：按规则核对

| 规则 | 落点 |
|---|---|
| 现代入口清单与 `module.prop` 字段 | 6.1 / 6.2 |
| `io.github.libxposed.*` 只能 compileOnly + 构建后自检 | 6.2 / 6.8 |
| 入口 `Application.attach(Context)` 与 ClassLoader 时机 | 6.3 |
| Toast + `VectorToastModule` 日志 | 6.3 / 6.6 |
| JDK17 / SDK / Gradle wrapper 三层探测与 preflight | 6.4 |
| Vector CLI 命令集与 `>=3043` 门禁 | 6.5 |
| 三行日志验证序列与 `cli log cat` | 6.6 |

### 9.5 冲突登记表

| 编号 | 冲突点 | 各方立场 | 裁决 | 理由 |
|---|---|---|---|---|
| C-01 | 用哪个反编译/反汇编引擎 | A：以 IDA 为中心（三篇 IDA 技能把 IDA 当唯一入口，主链路却规定 native 用 rizin 优先）；B：多 provider（Hopper/Ghidra/IDA/Kuna）+ 大量纯静态能力 | **取 B**：引擎按目标与是否需要深分析选择，rz/bin 工具做快速勘察 | A 内部自相矛盾；B 有明确的能力边界与 provider 降级语义 |
| C-02 | 脱壳是否是必经步骤 | A：加固必须先脱壳才能看真实代码；B：Android 路线是静态观测 + 运行时补证，无商用壳脱壳能力 | **改写成条件分支**（5.6） | 把脱壳写成通则会让无壳目标浪费大量时间，也会误述 REA 边界 |
| C-03 | Xposed 模块规范 | A：legacy API 82 + `assets/xposed_init`；C：现代 libxposed + `META-INF/xposed/*` | **取 C** | A 是旧版写法且 assets 路径有错；C 是当前可运行规范并带自检 |
| C-04 | A 语料规模自述 | A 全景分析：47 技能 / 231 文件；实测 263 文件 | **以实测为准**，并把差异登记 | 自述与实际不符，影响"覆盖率"判断 |
| C-05 | 是否原地修改样本 | A：直接改 APK/SO 并重打包重签，无哈希与回滚要求；B：原始与派生分离、保留回滚 | **取 B**（`samples/` 只读、`work/` 改动、补丁前后记哈希） | 可复现性与可回滚性优先 |
| C-06 | 动态结论需要什么锚点 | A：打印 console 即可；B：证据需 ID/权威/限制/覆盖/未知 | **取 B 的字段要求**，A 的 hook 配方保留 | A 的结论不可复核 |
| C-07 | `jadx --deobf` 是否默认开 | A 内部冲突：Jadx 篇建议"总是加"，Android逆向工程 篇要求"上动态前不要加" | **按阶段**：静态阅读可开，动态/hook 前必须用原始名重跑 | 别名在运行时不保证存在 |
| C-08 | `frida --no-pause` | A 的 Android动态分析 使用；A 的 Frida逆向 明确说现代 CLI 无此参数 | **取 Frida逆向** | 现代 CLI 行为已变 |
| C-09 | `zipalign` 与签名的顺序 | A 的 APK解包工具 把 zipalign 写在 jarsigner 之后 | **先 align 后 sign** | 顺序错会导致对齐信息失效 |
| C-10 | `assets/` 位置 | A 的 Xposed模块构建 放在工程根 | **放 `app/src/main/assets/`** | 位置错会静默不生效 |
| C-11 | IDA 是唯一入口还是可选 | A 的 IDA 三篇 vs A 主链路的 rizin 优先 | **以主链路为准**，IDA 用于深挖 | 与 C-01 同源，避免重复投入 |
| C-12 | 是否允许 LLM 直接改写符号 | A 的 `reai.py`（TEMPERATURE=0.7 直接回写函数名/注释） vs B 的证据化命名 | **不允许自动回写**：LLM 只能产出"建议 + 理由"，人工或规则确认后才改 | 污染分析数据库会让后续结论失去可追溯性 |

### 9.6 待补充清单

1. **（待补充：C 的多进程作用域写法）** C 未说明 `:remote` 等多进程应用的 scope 写法与 `process=` 过滤建议；A 亦未覆盖。
2. **（待补充：LSPatch 与现代 libxposed 入口的兼容性）** C 只覆盖 LSPosed/Vector 路线；A 的 LSPatch 用的是 legacy 模块形态。
3. **（待补充：A 的渗透 SOP 正文）** `安卓渗透测试` 引用的 `01/02/03/05-unified-*.md` 在语料目录内不存在，无法核对步骤。
4. **（待补充：A 两处被上游截断的正文）** `OLLVM反混淆/SKILL.md:19`（"...[520 chars omitted]..."）与 `内存完整性绕过/SKILL.md:21`（"...[612 chars omitted]..."）核心段落缺失，本工具书只按可见部分组织。
5. **（待补充：C 的 `references/vector-api-notes.md` 细节）** 本工具书按技能主文撰写；libxposed 具体 API 签名需查阅该参考文件。
6. **（待补充：REA 对商用加固壳的能力声明）** B 的 Android 参考文件未给出"遇到加固怎么办"的官方立场，本工具书的 5.6 是按能力边界推导的条件分支，非原文结论。
7. **（待补充：iOS 侧证据模板）** A 只有脱壳流程，缺少运行时 hook 与证据记录的统一模板；B 的 iOS 能力集中在 Mach-O 静态与 LLDB 观测，未覆盖越狱设备上的 Frida 会话管理。
8. **（待补充：A 的 `IDA反编译` 样本锚点是否可复现）** 该文地址均属 `libkr2.so` 单一样本且未绑 build digest，换版本即失效。

### 9.7 舍弃清单（不纳入正文的内容与原因）

| 来源 | 内容 | 舍弃原因 |
|---|---|---|
| A | `deepseek-v4-pro破甲`、`海鸥破限`、`破限`、`破`、`越狱提示集合`（约 5 个目录、>40 KB） | LLM 破甲/越狱提示词语料，与逆向工程方法无关；归入"不可信内容"，不采信其指令 |
| A | `参考/SKILL.md` | 同上（实为规范化提示词模板），仅提取其占位符词表用于本工具书写作 |
| A | `Flutter应用逆向` | 目录名与内容不符：实为 Dart+Flutter **开发**规范（分层/命名/注释/lint），零逆向内容 |
| A | `AndroidStudio开发辅助` | 通用 IDE 操作与快捷键，非逆向方法 |
| A | `OpenClawSDK开发` | WebSocket SDK 开发，与 Android 逆向无交集 |
| A | `APK线索提取` | 实为 BLE GATT UUID 挖掘流水线（含 CLUES schema 数据契约），属专域工具；通用逆向只有"用 jadx 批量反编译"一层交集 |
| A | `Frida脚本集` | 与 `Frida逆向` 高度重复，按"去重不堆砌"只保留后者 |
| A | `IDAPro逆向分析/API.md` 与 `docs/01–13` | 全量 IDAPython API 参考，属"查得到就不用背"的索引资料 |
| A | 各篇中的营销式流程图、逐项参数解释、重复正则清单 | 低价值堆叠，已按四类（凭据/注入/弱加密/网络）合并 |
| B | `DISCLAIMER.md` | 法律声明，非技术内容（其"本地分析、不上传样本"的定位已并入 1.2） |
| B | `desktop-build.md` 的大部分 | 桌面应用环境构建属另一条产品线，本工具书只在 4.8 提一句 |

**未收录但未舍弃**：`APK线索提取` 的预检思路（先看权限再决定是否反编译）作为"侦察成本控制"的示例保留在 2.2 的一句话里。

---

### 9.8 社区项目索引与整合建议

> **这节解决什么**：工具书前面写的是"该怎么做"，这节写"用谁做、能补哪一课"。**star 只作热度参考，不作选型依据**；选型看的是"它填的是本工具书的那一处空白"。数据为 2026-11-14 的 GitHub API 实时快照，引用时请连同日期一起记（这是第 7 章的证据要求）。

#### 9.8.1 采纳分级

| 级别 | 含义 | 处理方式 |
|---|---|---|
| **A 直接采纳** | 填的是本工具书的空缺位（引擎、底座、标准工具） | 直接进流程，写进对应章节 |
| **B 参考实现** | 不参与流程，但**代码/工程结构**值得读 | 读工程组织与适配写法，不照搬业务逻辑 |
| **C 教材与索引** | 学习路径与资源清单 | 新人入门用，不进操作流程 |
| **D 不采纳（留档）** | 已被取代或与定位不符 | **不删**：它们解释了"为什么今天这么做"的历史脉络 |

#### 9.8.2 主索引

| 项目 | ★ | 级 | 对应章节 | 它补的是什么 |
|---|---|---|---|---|
| [NationalSecurityAgency/ghidra](https://github.com/NationalSecurityAgency/ghidra) | 100.0k | A | 1.2 / 3.4 | 深分析 provider 本体；本工具书的伪代码/汇编面即它的输出 |
| [rizinorg/rizin](https://github.com/rizinorg/rizin) | 4.2k | A | 3.4 / 9.3 | `rz-bin/rz-strings` 的来源；**没有 provider 时的兜底勘察** |
| [rizinorg/cutter](https://github.com/rizinorg/cutter) | 20.2k | A | 3.4 | rizin 的 GUI：给"人工复核"一个界面，不必开 IDA |
| [radareorg/radare2](https://github.com/radareorg/radare2) | 25.4k | A | 3.4 | rizin 的上游，命令语法基本通用 |
| [unicorn-engine/unicorn](https://github.com/unicorn-engine/unicorn) | 9.6k | A | 3.4 | 片段模拟的底座，3.4 五原则直接跑在它上面 |
| [capstone-engine/capstone](https://github.com/capstone-engine/capstone) | 9.2k | A | 3.4 | 反汇编底座；写脚本解析指令时用它 |
| [horsicq/Detect-It-Easy](https://github.com/horsicq/Detect-It-Easy) | 11.9k | A | 5.1 / 9.1 | 壳与编译器指纹识别，可在 9.1 判型卡之前做机器初筛 |
| [bootleg/ret-sync](https://github.com/bootleg/ret-sync) | 2.4k | A | 4.5 | 调试器与反汇编器同步：动态看到的地址能立刻在静态视图里对上 |
| [skylot/jadx](https://github.com/skylot/jadx) | 51.8k | A | 3.3 | `--show-bad-code`/`--fallback` 这些参数的行为以它为准 |
| [iBotPeaches/Apktool](https://github.com/iBotPeaches/Apktool) | 27.2k | A | 3.3 / 5.5 | 资源与 smali 往返；回编报错的处理看它 issue |
| [pxb1988/dex2jar](https://github.com/pxb1988/dex2jar) | 13.2k | A | 3.3 | jadx 失败时的第二条 Java 路径 |
| [frida/frida](https://github.com/frida/frida) | 22.8k | A | 4.2–4.5 | 4.3 的 `android_dlopen_ext` 时机在它的 API 里有直接对应 |
| [sensepost/objection](https://github.com/sensepost/objection) | 9.5k | A | 4.4 | 免写脚本的运行时探索；`watch class_method` 就是它的命令 |
| [hluwa/frida-dexdump](https://github.com/hluwa/frida-dexdump) | 4.6k | A | 5.2 | 路线 B（内存 dump）的标准实现 |
| [Perfare/Il2CppDumper](https://github.com/Perfare/Il2CppDumper) | 9.7k | A | 5.3 | 5.3 版本—工具对照表的项目方 |
| [Perfare/Zygisk-Il2CppDumper](https://github.com/Perfare/Zygisk-Il2CppDumper) | 3.4k | A | 5.3 | metadata 被加密时的运行时 dump 路线 |
| [LSPosed/LSPosed](https://github.com/LSPosed/LSPosed) | 25.5k | A | 6.1 / 6.5 | 当前 Xposed 实现的参考；scope 语义以它为准 |
| [JingMatrix/Vector](https://github.com/JingMatrix/Vector) | 13.2k | A | 第 6 章 | **来源 C 的目标运行时**；`minApiVersion/targetApiVersion` 的定义处 |
| [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | 64.0k | A | 5.4 / 6.5 | 模块与 Zygisk 的宿主；CLI 与模块目录结构的依据 |
| [tiann/KernelSU](https://github.com/tiann/KernelSU) | 20.6k | A | 5.4 | 内核态 root：决定"能不能在内核层做手脚" |
| [bmax121/APatch](https://github.com/bmax121/APatch) | 8.2k | A | 5.4 | 另一条内核补丁路线 |
| [Dr-TSNG/ZygiskNext](https://github.com/Dr-TSNG/ZygiskNext) | 11.0k | A | 6.7 | 非 Magisk 环境下的 Zygisk，影响模块加载前提 |
| [yujincheng08/BiliRoaming](https://github.com/yujincheng08/BiliRoaming) | 11.5k | B | 6.2 / 6.3 | 现代模块的标准工程结构：入口、scope、多版本适配 |
| [cinit/QAuxiliary](https://github.com/cinit/QAuxiliary) | 5.8k | B | 6.3 / 6.8 | 大工程的 hook 组织与失效兜底（目标 App 一更新就全崩怎么办） |
| [ReChronoRain/HyperCeiler](https://github.com/ReChronoRain/HyperCeiler) | 5.7k | B | 6.2 | 系统级 hook 的资源与文案组织方式 |
| [LSPosed/CorePatch](https://github.com/LSPosed/CorePatch) | 3.6k | B | 5.4 | 签名校验绕过的成型实现，可对照本节的三处检测点 |
| [Dr-TSNG/Hide-My-Applist](https://github.com/Dr-TSNG/Hide-My-Applist) | 5.7k | B | 5.4 | 反检测的"被检测方视角"，写检测绕过前先读它 |
| [tiann/epic](https://github.com/tiann/epic) | 4.5k | B | 6.3 | ART 上的 Java AOP hook，理解 hook 原理比 API 更有用 |
| [CreditTone/hooker](https://github.com/CreditTone/hooker) | 5.3k | B | 4.4 | 把常用 hook 编排成 CLI 的思路 |
| [m0bilesecurity/RMS-Runtime-Mobile-Security](https://github.com/m0bilesecurity/RMS-Runtime-Mobile-Security) | 3.2k | B | 4.4 | Web 界面的运行时探索，适合给非脚本使用者 |
| [Ch0pin/medusa](https://github.com/Ch0pin/medusa) | 2.4k | B | 4.4 | 模块化编排（Android + iOS 同一套抽象） |
| [httptoolkit/frida-interception-and-unpinning](https://github.com/httptoolkit/frida-interception-and-unpinning) | 2.3k | B | 4.6 | pinning 绕过的现成脚本集，比手写 TrustManager 稳 |
| [Ylarod/Florida](https://github.com/Ylarod/Florida) | 2.3k | B | 5.4 | 反检测 frida-server：直接对应"查进程/扫内存"那一层 |
| [mrexodia/ida-pro-mcp](https://github.com/mrexodia/ida-pro-mcp) | 13.5k | B | 1.3 / 7 | MCP 桥接的工程范式；**但它没有证据语义**，正是第 7 章补的位 |
| [bethington/ghidra-mcp](https://github.com/bethington/ghidra-mcp) | 6.2k | B | 1.3 | 同上，且提供 headless 模式，可对照 1.3 的注册方式 |
| [zinja-coder/jadx-mcp-server](https://github.com/zinja-coder/jadx-mcp-server) | 0.8k | B | 1.3 / 3.3 | JADX 的 MCP 化，APK 侧的同类实现 |
| [decompiler-explorer/decompiler-explorer](https://github.com/decompiler-explorer/decompiler-explorer) | 2.7k | B | 3.4 | 同一函数多反编译器并排对比：验证"伪代码是推断不是源码"的最快方式 |
| [joernio/joern](https://github.com/joernio/joern) | 3.6k | C | 3.5 | 源码/字节码级 CPG 分析；二进制主线之外，做漏洞面扩展时用 |
| [KeenSecurityLab/BinAbsInspector](https://github.com/KeenSecurityLab/BinAbsInspector) | 1.7k | C | 3.4 | Ghidra 上的二进制漏洞扫描，属"有线索后再查"的工具 |
| [fkie-cad/cwe_checker](https://github.com/fkie-cad/cwe_checker) | 1.4k | C | 3.4 | 同上，CWE 模式检测 |
| [pwndbg/pwndbg](https://github.com/pwndbg/pwndbg) | 11.2k | C | 4.5 | 崩溃与漏洞向的 GDB 增强；本工具书主线用不到，做二进制漏洞时用 |
| [WerWolv/ImHex](https://github.com/WerWolv/ImHex) | 55.9k | C | 3.2 | 结构体与格式解析的交互式工具，配合 3.4 结构体逆向很顺手 |
| [x64dbg/x64dbg](https://github.com/x64dbg/x64dbg) | 50.3k | C | 4.5 | Windows 侧调试；本工具书以 Android/JS 为主，作为旁支 |
| [OWASP/mastg](https://github.com/OWASP/mastg) | 13.3k | C | 2.2 / 7.5 | 移动安全测试的方法论框架，可与本工具书的验收清单互补 |
| [mytechnotalent/Reverse-Engineering](https://github.com/mytechnotalent/Reverse-Engineering) | 15.2k | C | 0 | 从零基础到多架构的教程，新人补课用 |
| [alphaSeclab/awesome-reverse-engineering](https://github.com/alphaSeclab/awesome-reverse-engineering) | 5.2k | C | 9.8 | 全平台资源清单（与本表重复度高，按需查） |
| [morluto/awesome-reverse-engineering](https://github.com/morluto/awesome-reverse-engineering) | 2.1k | C | 9.8 | 同名不同作者的清单，偏工具与格式 |
| [AllsafeCyberSecurity/awesome-ghidra](https://github.com/AllsafeCyberSecurity/awesome-ghidra) | 1.5k | C | 3.4 | Ghidra 插件与脚本 |
| [awesome-android-root/awesome-android-root](https://github.com/awesome-android-root/awesome-android-root) | 6.0k | C | 6.5 | root/模块生态索引，找现成模块比自己写快 |
| [Evil0ctal/AndroidReverse101](https://github.com/Evil0ctal/AndroidReverse101) | 0.5k | C | 0 | 中文入门路径 |
| [majd/ipatool](https://github.com/majd/ipatool) | 12.3k | D | 5.3 | **获取渠道**而非分析工具：用来拿 IPA，分析仍看 5.3 |
| [AloneMonkey/frida-ios-dump](https://github.com/AloneMonkey/frida-ios-dump) | 4.0k | A | 5.3 | 5.3 iOS 砸壳流程的上游实现 |
| [rovo89/Xposed](https://github.com/rovo89/Xposed) + [XposedBridge](https://github.com/rovo89/XposedBridge) | 7.7k / 4.1k | D | 6.1 | legacy 规范的**定义处**：只在读老模块、需要确认 API 语义时查 |
| [android-hacker/VirtualXposed](https://github.com/android-hacker/VirtualXposed) | 16.1k | D | 6.7 | 免 root 虚拟化的历史方案；新系统兼容性（待补充：需按目标 Android 版本核实） |
| [ElderDrivers/EdXposed](https://github.com/ElderDrivers/EdXposed) | 5.7k | D | 6.1 | 已被 LSPosed 取代，保留作演进脉络 |
| [kdrag0n/safetynet-fix](https://github.com/kdrag0n/safetynet-fix) | 6.4k | D | 5.4 | SafetyNet 已被 Play Integrity 取代；思路（改属性+拦截查询）仍有效 |

#### 9.8.3 三个真正互补的地方（不是"多一个链接"，是"补一个洞"）

1. **`--show-bad-code` 这类"看不见的失败"**：工具书 3.3 只说"要加"，社区项目的 issue 与文档才解释"为什么加了才看得见"——jadx 在方法反编译失败时**默认不输出该方法**，不加参数就会误判"逻辑不在这里"。这类"默认行为的坑"工具书给不出，只能靠项目侧。
2. **版本—工具对照的实时性**：5.3 的 Unity 表（≤29 / 31 / 39）会随 Unity 与工具发版不断失效。Il2CppDumper 与其 v39 分支、`Zygisk-Il2CppDumper` 的 issue 是这张表的**唯一权威来源**——本工具书只能给"当前快照"，不能替代查证。
3. **证据语义的缺口**：`ida-pro-mcp`（13.5k）与 `ghidra-mcp`（6.2k）把工具暴露给模型，但**返回值里没有权威度、覆盖范围、剩余未知**。第 7 章那套字段正好补这个洞；反过来，它们的 GUI+headless 双模式值得 1.3 借鉴（`inspect_*` 与 `analyze_*` 的分工）。

#### 9.8.4 使用纪律

- **把 9.8 当选型表，不当依赖清单**：本书不要求你安装其中任何一个；1.2 的 provider 与 9.2 的矩阵仍然是决策入口。
- **star 会骗人**：`Awesome-Hacking` 125.5k 是清单、`x64dbg` 50.3k 与 Android 主线无关、`VirtualXposed` 16.1k 但停更。**看维护状态与 issue 质量，不看数字**。
- **引用外部项目要带版本**：写进报告时记 `owner/repo@tag|commit` + 查证日期，否则半年后无法复核（与第 7 章的证据要求同源）。
- **不复制它们的业务代码**：B 类项目的价值是工程结构与适配写法；把别人的 hook 逻辑抄进交付物，会把对方的假设一起带进来。

### 文档维护说明

- **版本基准**：来源 B 对应 `rea-agents` 6.9.0（`skills/reverse-engineer-anything/SKILL.md` 的 `metadata.version` 为 62、`tool_count` 为 255）；来源 A 为 2026-11 快照（263 文件）；来源 C 为技能主文当前版本。
- **更新原则**：REA 的工具名、参数与错误码以你所用版本的实际 schema 为准；A 的命令以工具当前 `--help` 为准；C 的入口规范以 Vector 当前 `minApiVersion` 为准。三者在版本升级后若与本工具书冲突，**先按 9.5 的裁决顺序判断归属**，再更新对应章节并在 9.5 追加一行。
- **新增内容的落点**：新目标类型 → 3.5 的表；新反检测手段 → 5.4 的分层表；新模块规范 → 6.1 的对照表；新反模式 → 8.3 的编号表。
