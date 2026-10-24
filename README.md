# Android CTF 逆向 — Agent 作业规范

> 一套给 **AI Agent 用的 Android 逆向 / CrackMe 作业规范**。不是工具集，是规则书。
>
> 把整份提示词喂给 agent，发一个激活词加一个 APK，它就把整条链路跑完——产出七章分析报告，或者一个能装能跑的破解包。

[English](README.en.md) · **简体中文**

---

## 这是什么

大多数 agent 做逆向时的毛病是：东一榔头西一棒子、不打招呼就碰设备、写一堆漂亮文章但交不出结果、没测就说"已解锁"、改完自己都忘了改过哪。

这个项目把一套**写死的作业流程**塞进提示词，让 agent 只能按规矩干活。

| Agent 做逆向的通病 | 这份规范怎么治 |
|---|---|
| 东一榔头西一棒子 | 固定阶段流水线，每阶段产物是下一阶段输入 |
| 不打招呼就碰设备 | 静态优先铁律；真机必须先告知，且每一步单独请求 |
| 写漂亮文章不交结果 | Evidence / Finding / Path 编号制，没有证据编号的报告不算数 |
| 没测就说"已解锁" | 必须逐项点开功能到实际可用，"假成功"是硬违规 |
| 改了什么都记不住 | 每处 patch 强制记录：文件、行号、改前、改后、目的 |
| 编造工具输出 | 禁止伪造；跑不通就如实写失败原因与已排除的可能 |
| 自己把破解包装上去 | 交付停在签名后的 apk 路径，装包和试用交给用户 |

---

## 核心特性

- **双激活词** —— `bushi` 走分析、`nima` 走破解，两条链路互不干扰
- **静态优先** —— 默认纯电脑干活，不用模拟器；真机是最后手段，且必须先问
- **占位符路径** —— 所有路径用 `<TOOLROOT>` 这类占位符，换机器只改一张表
- **固定报告骨架** —— 七章分析 / 八章破解，不增不减章节
- **可复现** —— 每条结论带证据编号和可粘贴执行的命令

---

## 快速开始

```bash
git clone https://github.com/UserCrazyLove/android-ctf-re-agent.git
cd android-ctf-re-agent
```

然后：

1. 读 **[本地搭建指南](GETTING-STARTED.zh-CN.md)** —— 从零装工具链到跑通第一条命令
2. 把 `prompts/ctf-reverse-system.md` 里的路径表换成你自己的（参考 [占位符说明](prompts/env.example.md)）
3. 整份提示词喂给 agent
4. 发激活词

```
bushi                          → agent 回「我准备好了，请发我apk」
bushi D:/cases/CrackMe01.apk   → 跑完整分析链路
nima  D:/cases/CrackMe01.apk   → 跑完整破解链路
```

---

## 两个激活词

| 词 | 模式 | 交付物 |
|---|---|---|
| `bushi` | 逆向分析 | 七章 `report.md` + flag / 关键类名 |
| `nima` | CrackMe 破解 | 可安装破解包 + patch 清单 + 回归测试矩阵 |

只发词不带包 → agent 回「我准备好了，请发我apk」然后停住等。
带包发 → 直接开跑，不再确认。

---

## 文档导航

### 新手必读

| 文档 | 内容 |
|---|---|
| **[本地搭建指南](GETTING-STARTED.zh-CN.md)** | 从 clone 到跑通第一条命令，三平台工具链安装、路径映射、冒烟测试、agent 接入、14 项检查清单 |
| [English Setup Guide](GETTING-STARTED.md) | 同上，英文版 |

### 核心提示词

| 文件 | 说明 |
|---|---|
| **[prompts/ctf-reverse-system.md](prompts/ctf-reverse-system.md)** | ★ 完整作业规范，主交付物 |
| [prompts/ctf-reverse-system.lite.md](prompts/ctf-reverse-system.lite.md) | 精简版，保留工作流与硬约束，上下文紧张时用 |
| [prompts/env.example.md](prompts/env.example.md) | 占位符总表 + Windows / Linux / macOS 三套配置 + 替换方法 |

### 方法论

| 文档 | 内容 |
|---|---|
| [docs/crackme-playbook.md](docs/crackme-playbook.md) | 四条破解需求（去验证 / 去自检 / 本地化 / 去协议）的方法论展开，含常见失败模式对照 |
| [docs/anti-tamper-checklist.md](docs/anti-tamper-checklist.md) | 反分析 / 反篡改 / 反环境 / 暗桩 / 混淆 / 时间授权 检测点全表，加八步加载失败回查顺序 |
| [docs/setup-toolchain.md](docs/setup-toolchain.md) | 每个工具的安装步骤 + 验证命令 + 版本对照表 |
| [docs/faq.md](docs/faq.md) | 七类常见问题：环境、解包、签名、动态、破解、agent、工作区 |

### 流程演示

| 文档 | 内容 |
|---|---|
| [examples/README.md](examples/README.md) | `bushi` 和 `nima` 两条链路从开案到交付的完整演示（虚构样本） |

### 其他

| 文档 | 内容 |
|---|---|
| [requirements.md](requirements.md) | 依赖与环境要求 |
| [CHANGELOG.md](CHANGELOG.md) | 版本记录 |
| [LICENSE](LICENSE) | MIT |

---

## 目录结构

```
android-ctf-re-agent/
├─ README.md                      本文件（中文主说明）
├─ README.en.md                   英文主说明
├─ GETTING-STARTED.zh-CN.md       ★ 本地搭建指南（中文）
├─ GETTING-STARTED.md             本地搭建指南（英文）
├─ requirements.md                依赖说明
├─ LICENSE / CHANGELOG.md
│
├─ prompts/                       提示词
│  ├─ ctf-reverse-system.md       ★ 完整规范
│  ├─ ctf-reverse-system.lite.md  精简版
│  └─ env.example.md              占位符配置
│
├─ workspace/                     案子脚手架
│  ├─ new_case.sh                 开案脚本（bash）
│  ├─ new_case.ps1                开案脚本（PowerShell）
│  ├─ _report-template.md         七章分析报告骨架
│  ├─ _crackme-template.md        八章破解报告骨架
│  └─ scripts/                    跨案公用脚本
│
├─ docs/                          方法论与工具文档
│  ├─ setup-toolchain.md
│  ├─ crackme-playbook.md
│  ├─ anti-tamper-checklist.md
│  └─ faq.md
│
└─ examples/
   └─ README.md                   流程演示
```

---

## 设备策略（最容易做错的地方）

三个层级，agent 被要求一直待在第一层：

| 档 | 内容 | 规则 |
|---|---|---|
| **纯静态** | 判壳、解包、反编译、SO 反汇编、unidbg、patch 回编签名、Python 对拍 | 默认，永远从这里开始 |
| **真机** | frida / objection / 抓包 / UI 定位 | 静态做不到才用：说清卡点 → 等用户说开始 → 每步操作单独请求 |
| **模拟器** | —— | 不用。缺硬件加速跑不起来，结果也不代表真实环境 |

`adb devices` 里躺着你的手机，**不代表** agent 可以用它。

Crack 完成后也一样：agent 只给 apk 路径，**装包和试用由你自己做**。你反馈有问题，它才开始排查。

---

## 报告格式

两种模式都出固定骨架的 markdown 报告：

- **分析（七章）** —— 目标与结论 / Evidence (E-xxx) / Findings (F-xxx) / Path (P-xxx) / 复现脚本 / Timeline / 遗留问题
- **破解（八章）** —— 结论 / 样本指纹 / 校验点清单 / Patch 清单 / 反篡改处理记录 / 本地化改造记录 / 回归测试矩阵 / 残留问题

每条结论都带证据编号。没有证据的推断必须标 `confidence: low` 并进「遗留问题」。

---

## 适用环境

| 项 | 要求 |
|---|---|
| 操作系统 | Windows 10/11、Ubuntu 20.04+、macOS 12+ |
| Agent | 任何能跑 shell 的长上下文模型（Claude Code、Codex CLI、OpenCode、Cursor、Hermes 等） |
| 上下文 | 32K tokens 以上（完整提示词约 35 KB） |
| 磁盘 | 15 GB 空闲（工具链占用） |

详细依赖见 [requirements.md](requirements.md)。

---

## 适用范围

面向 CTF 靶场、自建题目、以及你有完整控制权的样本。提示词开头就把授权前提写死了，避免 agent 在范围问题上打转。请在你有权分析的靶标上使用。

---

## 贡献

欢迎 issue 和 PR，尤其是：

- 反篡改检测点的新套路
- 还没覆盖到的平台工具链笔记
- 文档翻译

提示词的结构请保持原样 —— 它是刻意写死的。

---

## 许可

[MIT](LICENSE)
