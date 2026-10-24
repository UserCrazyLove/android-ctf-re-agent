# Android CTF 逆向 — Agent 作业规范

一套给 **AI Agent 用的 Android 逆向 / CrackMe 作业规范**。不是工具集，是规则书。把整份提示词喂给 agent，发一个激活词加一个 APK，它就把整条链路跑完，产出报告或者一个能装的破解包。

- **适用**：任何能跑 shell 的长上下文 agent（Claude Code、Codex CLI、OpenCode、Cursor、Hermes 等）
- **对象**：自建靶场里的 APK / DEX / SO / 加固样本
- **两种模式**：分析（`bushi`）与 CrackMe 破解（`nima`）

---

## 它到底约束了什么

| Agent 做逆向时的通病 | 这份规范怎么治 |
|---|---|
| 东一榔头西一棒子 | 固定 6 阶段流水线，每阶段产物是下一阶段输入 |
| 不打招呼就碰设备 | 静态优先铁律；用真机必须先告知，且每一步单独请求 |
| 写漂亮文章不交结果 | Evidence / Finding / Path 编号制，没有证据编号的报告不算数 |
| 没测就说"已解锁" | 必须逐项点开功能到实际可用，"假成功"是硬违规 |
| 改了什么都记不住 | 每处 patch 强制记录：文件、行号、改前、改后、目的 |
| 编造工具输出 | 禁止伪造；跑不通就如实写失败原因与已排除的可能 |
| 自己把破解包装上去 | 交付停在签名后的 apk 路径，装包和试用交给用户 |

---

## 五分钟上手

```bash
git clone <本仓库> android-ctf-re
cd android-ctf-re

# 1. 先读本地搭建指南
cat GETTING-STARTED.md

# 2. 填自己的路径
cp prompts/env.example.md prompts/env.local.md
#    ... 编辑 prompts/env.local.md ...

# 3. 打开提示词，把"环境事实"那节的路径表换成你自己的
#    prompts/ctf-reverse-system.md

# 4. 整份文件作为系统提示词喂给 agent
# 5. 发激活词
```

然后在对话里：

```
bushi                           → agent 回「我准备好了，请发我apk」
bushi D:/cases/CrackMe01.apk    → 跑完整分析链路
nima  D:/cases/CrackMe01.apk    → 跑完整破解链路
```

完整步骤见 **[GETTING-STARTED.md](GETTING-STARTED.md)**。

---

## 目录结构

```
android-ctf-re/
├─ README.md                     英文说明
├─ README.zh-CN.md               本文件
├─ GETTING-STARTED.md            ★ 本地搭建 + 构建指南（从这开始）
├─ LICENSE                       MIT
├─ CHANGELOG.md
│
├─ prompts/
│  ├─ ctf-reverse-system.md      ★ 完整提示词（核心交付物）
│  ├─ ctf-reverse-system.lite.md 精简版（约 200 行，上下文紧张时用）
│  └─ env.example.md             占位符说明 + 三种典型配置
│
├─ workspace/                    案子脚手架
│  ├─ new_case.sh                bash 开案脚本（Linux / macOS / git-bash）
│  ├─ new_case.ps1               PowerShell 开案脚本（Windows）
│  ├─ _report-template.md        分析报告，七章
│  ├─ _crackme-template.md       CrackMe 报告，八章
│  └─ scripts/                   跨案公用脚本
│
├─ docs/
│  ├─ setup-toolchain.md         从零装整套工具链
│  ├─ crackme-playbook.md        四条破解需求的方法论展开
│  ├─ anti-tamper-checklist.md   检测点全表，可当 checklist 用
│  └─ faq.md                     常见卡点与报错对照
│
└─ examples/
   └─ README.md                  流程演示（不放真实样本）
```

---

## 两个激活词

| 词 | 模式 | 交付物 |
|---|---|---|
| `bushi` | 逆向分析 | 七章 `report.md` + flag / 关键类名 |
| `nima` | CrackMe 破解 | 可安装破解包 + patch 清单 + 回归测试矩阵 |

只发词不带包 → agent 回「我准备好了，请发我apk」然后停住等样本。
带包发 → 直接开跑，不再确认。

---

## 设备策略（最容易做错的地方）

三个严格层级，agent 被要求一直待在第一层：

1. **纯静态** —— 判壳、解包、反编译、SO 反汇编、unidbg、patch 回编签名、Python 对拍。**一切从这里开始，大多数工作也在这里结束。**
2. **真机** —— 只在静态确实答不出来时用（壳只运行时释放 DEX、TEE / KeyStore、厂商 ROM 行为、反调试必须真机、必须看真实 UI）。流程：说清卡点 → 等用户说开始 → **每一步**设备操作单独请求。
3. **模拟器** —— 不用。多数机器缺硬件加速跑不起来，跑起来也不代表真实环境，结论不可信。

`adb devices` 里躺着你的手机，**不代表** agent 可以用它。

---

## 报告格式

两种模式都出固定骨架的 markdown 报告，不多不少章节：

- **分析** —— 目标与结论 / Evidence (E-xxx) / Findings (F-xxx) / Path (P-xxx) / 复现脚本 / Timeline / 遗留问题
- **CrackMe** —— 结论 / 样本指纹 / 校验点清单 / Patch 清单 / 反篡改处理记录 / 本地化改造记录 / 回归测试矩阵 / 残留问题

每条结论都带证据编号。没有证据的推断必须标 `confidence: low` 并进「遗留问题」。

---

## 适用范围

面向 CTF 靶场、自建题目、以及你有完整控制权的样本。提示词开头就把授权前提写死了，避免 agent 在范围问题上打转。请在你有权分析的靶标上使用。

---

## 许可

MIT，见 [LICENSE](LICENSE)。

## 贡献

欢迎 issue 和 PR，尤其是：

- 反篡改检测点的新套路
- 还没覆盖到的平台工具链笔记
- 文档翻译

提示词的结构请保持原样 —— 它是刻意写死的。
