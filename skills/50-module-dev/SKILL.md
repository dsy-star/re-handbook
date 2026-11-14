---
name: module-dev
description: 构建、修改、启用并验证 Vector/LSPosed 现代 libxposed 模块（META-INF/xposed 入口）。用于"写个模块""模块装了没反应""要加注入提示"。
---

# 50 Android 模块开发（Xposed / Vector）

## 规范只有一套：modern（BOOK 6.1 / C-03）

| 项 | modern（本仓库标准） | legacy（只用于读老模块） |
|---|---|---|
| 入口声明 | `META-INF/xposed/module.prop` + `META-INF/xposed/java_init.list` | `assets/xposed_init` 单行 |
| Manifest | 不需要 `xposedmodule` meta-data | 三个 meta-data（含 `xposedminversion`） |
| 依赖 | `compileOnly` libxposed 桩 | `compileOnly xposed:api:82` |
| 入口钩子 | `Application.attach(Context)` | `IXposedHookLoadPackage.handleLoadPackage` |

`module.prop` 关键字段：`minApiVersion=101`、`targetApiVersion=101`、`staticScope=false`。`targetApiVersion=100` 在新版 Vector 可能不按 modern 加载。

## 怎么做

```bash
# 1) 从模板起步
cp -r templates/* <你的模块目录>/    # module.prop / java_init.list / MainHook.java 片段

# 2) 业务 hook 只能放在 Application.attach(Context) 之后
#    用 attach 传入的 Context.getClassLoader() 解析目标类
#    不要在 onPackageLoaded 阶段用模块自己的 loader 去 findClass

# 3) 构建（不要假设全局 gradle）
bash scripts/preflight.sh                 # JDK17 / SDK / wrapper
bash scripts/build_debug.sh               # 或 ./gradlew :app:assembleDebug

# 4) 包自检（桩是否泄漏、入口是否在）
bash ../40-unpack-bypass/scripts/verify-apk.sh app/build/outputs/apk/debug/app-debug.apk --module

# 5) 安装 + 探测 Vector 版本（>=3043 才允许自动改状态）
bash scripts/vector-cli.sh status --json
bash scripts/vector-cli.sh enable com.example.module
bash scripts/vector-cli.sh scope-add com.example.module com.example.target/0

# 6) 验证（期望三行日志）
bash scripts/verify-inject.sh com.example.target
```

## 三条纪律

1. **必须给用户可见反馈**（除非明确要求静默）：`Vector 注入成功: <target-package>`，日志 tag `VectorToastModule`。
2. **Vector CLI 版本门禁**：`Version Code < 3043` 时只装 APK、**不改模块状态**，让用户手动手册启用并配 scope。
3. **构建前置三层探测**：`$JDK_HOME` → `$ANDROID_HOME` → wrapper；显式传 `-Dorg.gradle.java.home`。

## 验证不通过时

| 日志 | 含义 | 处理 |
|---|---|---|
| `Loaded module ... successfully.` 缺失 | 模块未被加载 | 检查 module.prop 与 java_init.list 是否在 APK 里 |
| `Failed to instantiate` | 入口类名/包名不对 | 核对 `java_init.list` 里的全限定名 |
| `Class does not extend` | 入口未继承正确基类 | 按 libxposed 的入口类型改 |
| 有加载、无 `injected package=` | attach 没触发 | scope 是否包含目标包；目标是否被 force-stop 后重启 |

→ 工程结构与时序：[BOOK 6.2–6.3](../../BOOK.md) ｜ 失败对照表：[BOOK 6.8](../../BOOK.md)
