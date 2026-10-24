# Android CTF Reverse Engineering — Agent Playbook

An **operating spec for AI coding agents** that do Android reverse engineering and CrackMe solving in CTF labs. Not a tool collection — a rulebook. You hand the whole prompt to an agent, send an activation word plus an APK, and it runs the full chain and produces a report or a working cracked build.

- **Works with**: any long-context agent that can run shell commands (Claude Code, Codex CLI, OpenCode, Cursor, Hermes, etc.)
- **Targets**: APK / DEX / SO / packed samples in a self-hosted lab
- **Two modes**: analysis (`bushi`) and CrackMe cracking (`nima`)

---

## What it actually enforces

| Problem with agent-driven RE | What this spec does |
|---|---|
| Agent pokes around aimlessly | Fixed 6-stage pipeline, each stage's output feeds the next |
| Agent touches a device without asking | Static-first rule; device use requires explicit user go-ahead, per step |
| Agent writes pretty prose instead of results | Evidence/Finding/Path numbering; report rejected without evidence IDs |
| Agent says "unlocked" without testing | Must click every feature until actually usable; "fake success" is a hard violation |
| Agent forgets what it changed | Every patch must be logged: file, line, before, after, purpose |
| Agent invents tool output | Fabricated output forbidden; failed commands must be reported honestly |
| Agent installs the cracked APK itself | Delivery stops at the signed APK path; the user installs and tests |

---

## Quick start (5 minutes)

```bash
git clone <this-repo> android-ctf-re
cd android-ctf-re

# 1. Read the local setup guide FIRST
cat GETTING-STARTED.md

# 2. Fill in your own paths
cp prompts/env.example.md prompts/env.local.md
#    ... edit prompts/env.local.md ...

# 3. Open the prompt, replace the path table with yours
#    prompts/ctf-reverse-system.md  →  section "环境事实"

# 4. Feed the whole file to your agent as system prompt
# 5. Send the activation word
```

Then in the chat:

```
bushi                          → agent replies "我准备好了，请发我apk"
bushi D:/cases/CrackMe01.apk   → runs the full analysis chain
nima  D:/cases/CrackMe01.apk   → runs the full crack chain
```

Full walkthrough: **[GETTING-STARTED.md](GETTING-STARTED.md)**

---

## Repository layout

```
android-ctf-re/
├─ README.md                      this file
├─ README.zh-CN.md                中文说明
├─ GETTING-STARTED.md             ★ local setup + build guide (start here)
├─ LICENSE                        MIT
├─ CHANGELOG.md
│
├─ prompts/
│  ├─ ctf-reverse-system.md       ★ the full playbook (main deliverable)
│  ├─ ctf-reverse-system.lite.md  compact version (~200 lines, tight context)
│  └─ env.example.md              placeholder table + example configs
│
├─ workspace/                     case scaffolding
│  ├─ new_case.sh                 bash opener (Linux / macOS / git-bash)
│  ├─ new_case.ps1                PowerShell opener (Windows)
│  ├─ _report-template.md         analysis report, 7 chapters
│  ├─ _crackme-template.md        CrackMe report, 8 chapters
│  └─ scripts/                    shared scripts across cases
│
├─ docs/
│  ├─ setup-toolchain.md          install the whole toolchain from zero
│  ├─ crackme-playbook.md         the four crack requirements, expanded
│  ├─ anti-tamper-checklist.md    every detection point, as a checklist
│  └─ faq.md                      common blockers and error messages
│
└─ examples/
   └─ README.md                   workflow walkthrough (no real samples)
```

---

## The two activation words

| Word | Mode | Deliverable |
|---|---|---|
| `bushi` | Reverse analysis | `report.md` with 7 chapters + flag / key class names |
| `nima` | CrackMe cracking | Installable cracked APK + patch list + regression matrix |

Send the word alone → the agent replies `我准备好了，请发我apk` and waits.
Send the word with an APK path → it starts immediately, no confirmation.

---

## Device policy (the part people get wrong)

Three strict levels, and agents are required to stay on level 1:

1. **Pure static** — judge the packer, unpack, decompile, disassemble SO, unidbg, patch, rebuild, sign, Python cross-check. **This is where everything starts and where most work finishes.**
2. **Real device** — only when static genuinely cannot answer (packer only releases DEX at runtime, TEE / KeyStore, vendor ROM behaviour, anti-debug that needs real hardware, real UI needed). Requires: state the blocker → wait for the user to say go → request permission for **each** device operation.
3. **Emulator** — not used. Hardware acceleration usually unavailable, and results don't represent a real device, so conclusions would be untrustworthy.

An APK sitting in `adb devices` is **not** permission to touch it.

---

## Reporting format

Both modes produce a fixed-skeleton markdown report, no chapters added or removed:

- **Analysis** — 目标与结论 / Evidence (E-xxx) / Findings (F-xxx) / Path (P-xxx) / 复现脚本 / Timeline / 遗留问题
- **CrackMe** — 结论 / 样本指纹 / 校验点清单 / Patch 清单 / 反篡改处理记录 / 本地化改造记录 / 回归测试矩阵 / 残留问题

Every conclusion carries an evidence ID. Conclusions without evidence must be marked `confidence: low` and listed as open questions.

---

## Scope

Built for CTF labs, self-built challenges, and samples you own or have full control over. The prompt states this authorization premise up front so the agent does not stall on scope questions. Use it on targets you have the right to analyse.

---

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome, especially:
- new detection patterns for the anti-tamper checklist
- toolchain notes for platforms not covered yet
- translations of the docs

Keep the prompt's structure intact — it is deliberately rigid.
