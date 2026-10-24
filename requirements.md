# 依赖声明

本项目**没有代码依赖** —— 它是提示词和脚手架脚本的集合。但使用它需要一套 Android 逆向工具链，见 `docs/setup-toolchain.md`。

---

## 必需

| 组件 | 版本 | 用途 |
|---|---|---|
| Python | 3.10+ | 大部分工具的运行环境 |
| JDK | 21（+ 8 备用） | jadx / Ghidra / apktool |
| apktool | 3.x | 解包回编 |
| jadx | 1.5.x（CLI） | 反编译 Java |
| dex-tools | 2.4.x | dex ↔ smali |
| Android SDK | platform-tools + build-tools + platforms | adb / aapt2 / apksigner / zipalign |

## Python 包

```bash
pip install androguard apkid frida-tools objection mitmproxy \
            pycryptodome lief capstone pyelftools
```

## 可选（按需）

| 组件 | 用途 | 何时需要 |
|---|---|---|
| Ghidra 12.x | so 反汇编 | 有 native 层 |
| radare2 6.x | so 快速分析 / 改字节 | 有 native 层 |
| unidbg 0.9.x | 无设备跑 so | so 里有关键算法 |
| frida-server | 动态 hook | 静态确实做不到时 |
| frida-dexdump | 内存脱壳 | 样本加壳 |
| wallbreaker | 堆对象枚举 | 找不到关键对象时 |
| r0capture | 全量流量抓取 | 有 SSL Pinning |
| CFR 0.152 | jadx 失败时兜底 | jadx 出 `// error` |

## 运行环境

| 项 | 建议 |
|---|---|
| 操作系统 | Windows 10/11 x64、Ubuntu 20.04+、macOS 12+ |
| 磁盘 | 15 GB 空闲 |
| 内存 | 8 GB（推荐 16 GB） |
| Shell | bash（Windows 用 git-bash）或 PowerShell |

## Agent 要求

| 项 | 要求 |
|---|---|
| 上下文 | 32K tokens 以上（完整版提示词约 35 KB） |
| 能力 | 能执行 shell 命令、读写文件 |
| 兼容 | Claude Code、Codex CLI、OpenCode、Cursor、Hermes 等 |

上下文吃紧时用 `prompts/ctf-reverse-system.lite.md`。
