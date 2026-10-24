# <样本名> 逆向分析报告

> 分析日期：<YYYY-MM-DD>
> 分析目标：`<WORKSPACE>\<样本名>\original.apk`
> 工具链：<实际用到的工具及版本>

## 1. 目标与结论

<一句话结论 + 关键类名/函数名/算法名 + flag 或关键值>

## 2. Evidence

### E-001

- title:
- observed_at:
- source_type: file | runtime | network | tool_output
- source_ref: `<文件:行号>` 或 `<hook 点>`
- content_hash:
- artifact_path:
- repro_command: |
    <可直接粘贴执行的命令>
- raw_excerpt: |
    <原始片段，不改写>
- linked_workitem: n/a
- supersedes: none

## 3. Findings

### F-001

- title:
- severity: n/a_re
- category: crypto | auth | native | obfuscation | network | other
- status: validated | accepted_risk | open
- evidence_ids: [E-001]
- location: `<类全名#方法签名>` 或 `<so!偏移>`
- impact:
- confidence: high | medium | low
- repro_steps:
  1.
- remediation: n/a for pure RE
- optional_attack:

## 4. Path

### P-001

- title:
- path_type: callflow | datflow | crypto
- start:
- goal:
- steps:
  1. action: <动作> — evidence: E-00x — finding: F-00x
- residual_risks:

## 5. 复现脚本

<完整可运行脚本，标注语言与依赖；脚本本体放本目录 scripts\ 下>

## 6. Timeline 摘要

- <日期>：<动作与结果>

## 7. 遗留问题

<还缺什么、需要什么手段才能确认、当前结论的边界在哪>
