# 部署方案（DEPLOY）

> 面向两类读者：**人**（照着敲）和 **AI Agent**（照着判定并执行）。
> 目标：在一台干净机器上，把「只读 → 静态分析 → 动态与模块开发」三层环境装到可用，并且**知道每层缺什么**。
> 原则：**先自检、再安装、装完复跑**。任何一步失败就停在该层，不要带着半套环境往下做。

---

## 0. 三分钟读法

| 你的目的 | 执行 |
|---|---|
| 只想读文档 | 什么都不用装，直接看 [BOOK.md](BOOK.md) |
| 只想静态分析 APK / ELF | 装 §4，跳过 §5 §6 |
| 要 hook、要脱壳、要写模块 | §4 + §5 + §6 全装 |
| 让 AI 接手 | 先跑 §7 的自检，把输出贴给它；它按 §8 的流程走 |

自检命令（唯一入口，先跑它再决定装什么）：

```bash
bash skills/00-deploy-env/scripts/check-env.sh
```

---

## 1. 三层目标与最小集

| 层 | 能做到 | 最小安装集 | 典型耗时 |
|---|---|---|---|
| **L0 只读** | 查流程、判据、模板 | 无（Markdown 阅读器） | 0 |
| **L1 静态** | 解包、反编译、读符号、看导入导出 | JDK 17+、jadx、apktool、rizin（或 REA 代调） | 15–30 min |
| **L2 动态 + 模块** | hook、脱壳、抓包、写并验证模块 | L1 + adb + 平台工具 + `frida-tools` + 设备端 `frida-server` + Android SDK + Gradle | 1–2 h |

**L1 的替代路线**：装 REA 之后，APK/ELF 的多数静态问题可以由 REA 调它自己的工具完成；但 `unzip`、`sha256sum`、`file` 这类系统工具仍然要自己装。

---

## 2. 平台前置

### 2.1 三平台差异（真会卡住的）

| 项 | macOS | Linux | Windows |
|---|---|---|---|
| 命令环境 | zsh/bash 均可 | bash | **Git Bash / MSYS**（不要用 cmd/PowerShell 跑本书脚本） |
| 路径写法 | `/Users/...` | `/home/...` | `D:/x` 或 `/d/x`；**`/tmp` 不是合法工作目录** |
| 包管理 | Homebrew | apt/dnf | winget 或 scoop |
| JDK 探测 | `/usr/libexec/java_home -v 17` | `update-alternatives --list java` | **必须手动设 `JDK_HOME`**（待补充：语料只给了 macOS 取向的探测顺序） |
| 仅本平台可用 | Hopper、部分 Apple 目标 | binwalk / unblob / tshark（固件与抓包路线） | — |

### 2.2 版本矩阵（不满足就别装）

| 组件 | 要求 | 不满足的后果 |
|---|---|---|
| Node.js（REA） | `^22.23.4 \|\| ^24.22.1 \|\| >=26.12.1` | REA 启动即报错 |
| JDK | 17（`java -version` 显示 17.x） | jadx / apktool / Gradle 行为异常 |
| `frida`（本机） | 与设备端 `frida-server` **同主版本** | 能连上但 hook 失败或崩溃 |
| adb | 能 `adb devices` 看到设备且状态为 `device` | 后续全断 |
| Python | 3.10+（仅 objection 等需要） | 可选 |

---

## 3. 安装 REA（分析引擎 + 证据层）

REA 是一个 MCP server，同包也带 CLI。**版本固定写死**，避免"今天能跑明天不能跑"。

### 3.1 不安装直接用（推荐先这样验证）

```bash
# 看版本（不需要常驻进程）
npx -y rea-agents@6.9.0 --version

# 纯 JS/ASAR 任务可以完全不用 MCP
npx -y rea-agents@6.9.0 analyze-javascript-application /abs/path/to/app --json
```

### 3.2 全局安装（CLI 常用时）

```bash
npm i -g rea-agents@6.9.0
rea --version
command -v rea && command -v node && node --version
```

### 3.3 注册为 MCP server

MCP 客户端配置里加（`mcpServers` 结构）：

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

要点：

- **技能 ≠ 注册。** 仓库里有 `reverse-engineer-anything` 这类技能说明，不代表 MCP 已经注册；两者互不证明。
- 注册由安装流程（`rea setup`）负责时，不要重复手工加，否则会出现两个 server。
- 注册后验证：`rea doctor --client <你的客户端> --json`。它只检查注册与配置，**不证明当前会话的连接已建立**。

### 3.4 常用环境变量

| 变量 | 用途 | 默认 |
|---|---|---|
| `REA_MCP_INPUT_SCHEMA_PROFILE` | 设为 `full` 放开精简过的输入 schema | 精简 |
| `REA_MCP_OUTPUT_SCHEMA_PROFILE` | `compact` / `off` 控制输出体积 | 默认 |
| `REA_JADX_MCP_JAR` | headless JADX 的 jar 绝对路径（APK 路线需要） | 无 |
| `REA_JADX_HEAP_MIB` | JADX 堆上限 | 依工具 |
| `REA_APKTOOL_COMMAND` / `REA_ADB_PATH` | 指定 apktool / adb 绝对路径 | PATH |
| `REA_TSHARK_COMMAND` / `REA_CAPINFOS_COMMAND` | pcap 路线（Linux） | PATH |
| `REA_GHIDRA_STARTUP_TIMEOUT_MS` | 大二进制首次分析放宽启动超时 | 330000 |
| `REA_BROWSER_EXECUTABLE` | Web/Electron 路线指定 Chromium 系浏览器 | 自动探测 |

### 3.5 升级与回滚

```bash
npm i -g rea-agents@6.9.0     # 升/降到指定版本
npm ls -g --depth=0 | grep rea
```

回滚 = 重装旧版本号。**不要**用 `@latest`，本书所有命令与证据语义都对齐 6.9.0。

---

## 4. 安装静态链（L1）

| 工具 | macOS | Debian/Ubuntu | Windows |
|---|---|---|---|
| JDK 17 | `brew install openjdk@17` | `sudo apt install openjdk-17-jdk` | `winget install Microsoft.OpenJDK.17` |
| jadx | `brew install jadx` | 官方 release 解压后加 PATH | `scoop install jadx` |
| apktool | `brew install apktool` | `sudo apt install apktool` | `scoop install apktool` |
| rizin | `brew install rizin` | `sudo apt install rizin` | `scoop install rizin` |
| 基础命令 | 自带 | `sudo apt install unzip file binutils` | Git Bash 自带 `unzip`/`file`/`sha256sum` |

安装后验证：

```bash
java -version 2>&1 | head -1
jadx --version ; apktool --version ; rizin -v
unzip -v | head -1 ; file --version | head -1
```

**jadx 内存**：大 APK 用 `export JAVA_OPTS="-Xmx4096m"`。`jadx` 自身没有 `-Xmx` 参数，必须给 JVM。

---

## 5. 安装动态链（L2-a）

### 5.1 本机侧

```bash
# 平台工具
brew install android-platform-tools          # macOS
sudo apt install android-tools-adb           # Debian/Ubuntu
winget install Google.PlatformTools          # Windows

# Frida 与 objection（建议 pipx 隔离）
pipx install frida-tools
pipx install objection

adb devices -l
frida --version
```

### 5.2 设备侧（root 或可写 system 的模拟器）

```bash
ABI=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
FV=$(frida --version)
echo "device abi=$ABI  local frida=$FV"
# 从 https://github.com/frida/frida/releases 取 frida-server-$FV-android-$ABI.xz
# 解压后：
adb push frida-server-$FV-android-$ABI /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
adb shell "su -c '/data/local/tmp/frida-server &'"      # 无 su 时用 adb root
adb shell "/data/local/tmp/frida-server --version"
frida-ps -U | head
```

三条硬要求：

1. **主版本必须一致**（`frida 16.x` ↔ `frida-server 16.x`），否则连上也会崩。
2. 设备需已授权（`adb devices` 显示 `device` 而不是 `unauthorized`）。
3. 反 Frida 检测严格的目标，Gadget 注入往往比 server 更稳（见 BOOK 5.4）。

### 5.3 抓包（可选）

```bash
# 设备侧全量抓包（需要 root）
adb shell "su -c 'tcpdump -i any -w /sdcard/capture.pcap -G 30 -W 1'"
adb pull /sdcard/capture.pcap .
```

HTTPS 解密需要系统证书或 pinning 绕过，属 BOOK 5.4 的范围，不在部署脚本内自动完成。

---

## 6. 安装模块链（L2-b）

仅在要写/改 Xposed、Vector 模块时需要。

```bash
# 1) JDK 17（同 §4），确认：
echo "$JDK_HOME"          # 建议显式导出
java -version 2>&1 | head -1

# 2) Android SDK（命令行工具）
#    下载 commandline-tools，然后：
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
yes | sdkmanager --licenses

# 3) 工程内不要依赖全局 gradle：模板自带 wrapper
./preflight.sh                 # 检查 JDK / SDK / wrapper
./build_debug.sh               # 或 ./gradlew :app:assembleDebug
```

工程要求（详见 BOOK 6.2 / 6.4）：

- `local.properties` 写 `sdk.dir=...`，**不入库**；
- Gradle 调用要显式 `-Dorg.gradle.java.home="$JDK17_HOME"`，别指望 `java -version` 指对；
- 现代入口是 `META-INF/xposed/module.prop` + `META-INF/xposed/java_init.list`，`assets/xposed_init` 只作 legacy 回退。

---

## 7. 自检：输出契约

```bash
bash skills/00-deploy-env/scripts/check-env.sh            # 人读
bash skills/00-deploy-env/scripts/check-env.sh --tsv      # 机器读
```

输出每行 `TOOL<TAB>STATUS<TAB>DETAIL`，`STATUS ∈ {OK, MISSING, OPTIONAL, WARN}`。

退出码：

| 码 | 含义 | 该怎么办 |
|---|---|---|
| 0 | 所需层齐全 | 继续任务 |
| 1 | 有 `MISSING` | 按 DETAIL 里的章节号安装后复跑 |
| 2 | 参数错误 | 看 `--help` |

分层跑：

```bash
bash skills/00-deploy-env/scripts/check-env.sh --layer L1
bash skills/00-deploy-env/scripts/check-env.sh --layer L2
```

---

## 8. AI 执行流程（严格按序）

```
1. 识别平台（uname -s）+ 是否有 bash
2. 跑 check-env.sh --layer L0
3. 问用户目标层：只要静态？还是要动态/模块？（不猜）
4. 跑对应 --layer 自检，得到 MISSING 列表
5. 逐项安装：一次一项 → 复跑自检 → 记录到 installed.tsv
6. 全绿后，跑 §7 的 L1/L2 验证命令
7. 读 BOOK 对应章节（AGENTS.md §3 的映射表）再开始分析
8. 交付时附：环境版本快照 + 未覆盖项 + 已知 WARN
```

失败分支：

| 现象 | 处理 |
|---|---|
| 包管理器需要 sudo 且不可用 | 停，输出手工命令给用户；不要尝试改系统权限 |
| Node 版本不满足 | 停，告知要求的版本区间；**不要**擅自升级全局 Node |
| `npm i -g` 权限错误 | 改用 `npx -y rea-agents@6.9.0` 免安装路径 |
| `adb devices` 看不到设备 | 停；提示开启 USB 调试并授权，不要反复 kill-server |
| `frida` 与 server 版本不一致 | 只提示版本号差距；下载/推送由用户确认后执行 |
| SDK 许可未接受 | 输出 `yes \| sdkmanager --licenses`，等用户确认 |

**禁止**：自动安装 Ghidra / IDA / Hopper / JEB；自动 `rea setup` 处理"plugin 报 missing"；静默关闭沙箱或提权；未经要求 `git push`。

---

## 9. 卸载与回滚

安装时记录一份清单（脚本会写 `work/installed.tsv`）：

```
2026-11-14T22:10:03	npm	rea-agents@6.9.0	global
2026-11-14T22:11:40	brew	jadx	-
```

回滚顺序：先撤全局包（`npm rm -g`、`brew uninstall`），再删 `~/.local/share/...` 手工安装目录，最后清 PATH 增行。设备侧不留残留：

```bash
adb shell "su -c 'rm -rf /data/local/tmp/frida-server /data/local/tmp/panda'"
```

---

## 10. 常见失败

| 症状 | 原因 | 处理 |
|---|---|---|
| `jadx: command not found` | 解压目录未加 PATH | 加 PATH 或改用绝对路径 |
| `java -version` 是 8/11 | 多 JDK 共存 | 显式 `JDK_HOME` + Gradle `-Dorg.gradle.java.home` |
| `apktool` 回编报资源错 | aapt2 版本或资源损坏 | `--use-aapt2` 或 `-r` 跳过资源（BOOK 5.5） |
| `unzip` 在 Windows 报路径错 | 传了 `/tmp/x` | 换 `D:/x` 或 `work/x` |
| REA 报 Node 版本 | engines 约束 | 换 Node，别打补丁绕过 |
| REA 首次分析超时 | Ghidra 首次导入慢 | 调 `REA_GHIDRA_STARTUP_TIMEOUT_MS`，不要重复同一调用 |
| MCP 工具全缺 | 只装了技能未注册 server | 按 §3.3 注册；`rea doctor` 只看注册 |

---

## 11. 交付前检查清单

- [ ] `check-env.sh --layer <目标层>` 退出码 0
- [ ] `work/installed.tsv` 有完整安装记录
- [ ] 版本快照（node/java/jadx/frida/adb/rea）已附在交付物里
- [ ] 已知 `WARN` 与未装的可选项写进"限制与未覆盖"
- [ ] 设备侧未留临时文件
- [ ] 没有把 `samples/` 或 `work/` 里的东西提交进仓库
