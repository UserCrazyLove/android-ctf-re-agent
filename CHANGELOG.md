# CHANGELOG

## [1.1.0] — 2026-10-29

### 新增

- **DexSQL 工作流**（`<TOOLROOT>/DexSQL/dexsql.exe`，0.1.1）：用 SQL 直查 apk/dex 的类、方法、字符串、字段、调用图，配合 jadx 形成「先定位再精读」的节奏
  - 阶段 1 静态分析重写为 8 小节：摸全貌 → 关键字定位 → 交叉引用追调用链 → jadx 精读 → 原始 smali → 混淆应对 → 表结构速查 → 分工表
  - C1 校验点清剿加 5 条批量查询（校验方法、签名完整性、反调试、调用关系、开关字段）
  - 已知坑新增 2 条：列名不是直觉名（`name` 而非 `method_name`）、dexsql 不做 Java 反编译
  - 精简版同步加入 dexsql 一行工作流
- `docs/setup-toolchain.md`：DexSQL 安装与验证小节 + PATH + 自检命令 + 版本表
- `docs/anti-tamper-checklist.md`：常用搜索命令改为「dexsql 首选 + rg 精查」两段
- `docs/crackme-playbook.md`：1.1 找功能开关改为 dexsql 起步；新增「定位工具的选择」对照表
- `docs/faq.md`：新增 DexSQL 专节（能力边界、列名坑、与 jadx 分工、缓存提速）
- `GETTING-STARTED.zh-CN.md` / `GETTING-STARTED.md`：安装步骤加入 DexSQL
- `examples/README.md`：第 4 步改为「先 dexsql 定位再解包」
- `requirements.md`：依赖表加入 DexSQL

### 定位

DexSQL 是检索与反汇编工具，**不是反编译器**。`dex → Java` 仍然只用 jadx；`dex → smali` 可用 `dexsql decode` 或 apktool。

## [1.0.0] — 2026-10-24

首个公开版本。

### 提示词

- `prompts/ctf-reverse-system.md` —— 完整作业规范，含：
  - 场景与授权声明（CTF 靶场前提，避免 agent 在范围问题上打转）
  - 双激活词：`bushi`（逆向分析）、`nima`（CrackMe 破解）
  - 静态优先铁律 + 真机第二档流程（先告知、等确认、每步单独请求）
  - 工具路径全部抽成尖括号占位符，跨机器可移植
  - 执行流程 A（分析）：阶段 0–5
  - 执行流程 B（CrackMe）：阶段 C0–C6，含校验点清剿、反篡改对抗、功能本地化、门禁拆除、patch 回编签名、回归测试清单
  - 双输出规范：七章分析报告 / 八章破解报告
  - 17 条硬约束 + 双模式交付自检清单
- `prompts/ctf-reverse-system.lite.md` —— 精简版，保留工作流与硬约束，上下文紧张时用
- `prompts/env.example.md` —— 占位符说明 + Windows / Linux / macOS 三套配置

### 工作区脚手架

- `workspace/new_case.sh` —— bash 开案脚本，支持 `analyze` / `crack` 两种模式，读 `WORKSPACE` 环境变量
- `workspace/new_case.ps1` —— PowerShell 版，同样的功能
- `workspace/_report-template.md` —— 七章分析报告骨架
- `workspace/_crackme-template.md` —— 八章破解报告骨架，含 11 行回归测试矩阵

### 文档

- `GETTING-STARTED.md` —— 从 clone 到跑通第一条命令的完整指南，含三平台工具链安装、路径映射、冒烟测试、agent 接入
- `docs/setup-toolchain.md` —— 工具链逐项安装 + 验证命令 + 版本对照表
- `docs/crackme-playbook.md` —— 四条破解需求的方法论展开
- `docs/anti-tamper-checklist.md` —— 反分析 / 反篡改 / 反环境 / 暗桩 / 混淆 / 时间授权 全表 + 加载失败八步回查 + 排查清单
- `docs/faq.md` —— 环境、解包、签名、动态、破解、agent、工作区七类常见问题
- `examples/README.md` —— 分析模式与破解模式的完整流程演示

### 设计决策

- **路径用尖括号占位符**而非 shell 变量：与文档里已有的 `<样本名>` `<案名>` `<pkg>` 风格统一，一眼认出需替换
- **提示词结构刻意写死**：不增不减章节，保证输出可预期
- **模拟器不使用**：硬件加速普遍缺失，且结果不代表真实设备
- **Crack 完不自己装机**：交付停在签名后的 apk 路径，装包测试交用户
