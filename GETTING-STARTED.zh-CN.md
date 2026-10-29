# 本地搭建指南 — 从 clone 到跑通第一条命令

这份文档解决三件事：

1. 从 GitHub 拿到项目，落到你本地
2. 把工具链按项目要求装齐、路径对上
3. 跑通第一条开案命令，确认能用

全程约 40–60 分钟，其中大半是下载时间。**每一步都有验证命令，验证不过就别往下走。**

> 英文版：[GETTING-STARTED.md](GETTING-STARTED.md)

---

## 0. 你需要什么

| 项 | 最低要求 | 说明 |
|---|---|---|
| 操作系统 | Windows 10/11 x64、Ubuntu 20.04+、macOS 12+ | 三条都有对应的安装路线 |
| 磁盘 | 15 GB 空闲 | JDK 两个版本 + SDK + Python 环境 + Ghidra 占大头 |
| 内存 | 8 GB（推荐 16 GB） | Ghidra 吃内存 |
| 网络 | 能下 GitHub / Google / PyPI | 国内建议备好代理或镜像，见 §3.5 |
| 一个长上下文 Agent | 32K tokens 以上 | Claude Code / Codex CLI / OpenCode / Cursor / Hermes 都行 |
| 一个 APK | CrackMe 或你自己的样本 | 只做静态分析的话不需要手机 |

**不需要**：Android 手机（除非后面静态确实卡住，才按提示词的第二档流程申请）、Android Studio 完整版。

---

## 1. 在 GitHub 找到项目并拉到本地

### 1.1 找项目

用下面任意一种方式定位：

- **直接搜索**：GitHub 搜 `android ctf reverse agent playbook`、`android-crackme-agent`、`bushi nima 逆向`
- **按 topic 找**：仓库打了 `android-reverse-engineering`、`ctf`、`crackme`、`ai-agent`、`prompt-engineering` 这些 topic，点 topic 标签能筛出同类项目
- **按文件找**：GitHub 代码搜索里搜文件名 `ctf-reverse-system.md`，本项目的主提示词就叫这个

认准仓库根目录有 `prompts/ctf-reverse-system.md` 和 `GETTING-STARTED.md`（就是本文件）。

### 1.2 克隆

```bash
# HTTPS（推荐，最省事）
git clone https://github.com/UserCrazyLove/android-ctf-re-agent.git

# 或者先 fork 再 clone 自己的
git clone https://github.com/<你的用户名>/android-ctf-re-agent.git
```

没装 git：

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y git curl unzip

# macOS
brew install git

# Windows
winget install --id Git.Git -e
```

**不想用 git**：仓库页面右上角 `Code` → `Download ZIP`，解压后重命名为 `android-ctf-re`，效果一样（但没有 `git pull` 更新能力）。

### 1.3 验证

```bash
cd android-ctf-re-agent
ls
```

必须看到：

```
README.md  README.en.md  GETTING-STARTED.md  GETTING-STARTED.zh-CN.md
LICENSE  CHANGELOG.md  requirements.md  .gitignore  .gitattributes
prompts/  workspace/  docs/  examples/
```

看到这些说明拿到了完整项目。少任何一个说明 clone 不完整，删掉重来。

---

## 2. 规划你的目录（重要，别跳）

项目里所有路径都用尖括号占位符，**你必须先把它们映射到自己的实际路径**。

### 2.1 选一个根目录

推荐结构（Windows）：

```
D:\Android\
├─ tools\                     ← 工具 + 运行时（本项目的 <TOOLROOT>）
│  ├─ apktool\
│  ├─ jadx\
│  ├─ dex-tools\
│  ├─ frida\
│  ├─ ghidra\
│  ├─ unidbg\
│  ├─ radare2\
│  ├─ scripts\                ssl-unpinning.js / root-bypass.js / r0capture.py
│  ├─ signer\                 你的签名证书
│  ├─ java-decompiler\        cfr.jar
│  ├─ jdk21\
│  ├─ jdk8\
│  └─ venv\                   Python 环境
├─ AndroidSDK\                ← <SDKROOT>
└─ workspace\                 ← <WORKSPACE>，一案一目录
```

Linux / macOS：

```
~/android-re/
├─ tools/
├─ sdk/
└─ workspace/
```

**工具和运行时全部塞进 `tools\`，工作区单独放。** 这是项目约定的结构，后面所有脚本都按这个找东西。

### 2.2 填写占位符表

打开 `prompts/ctf-reverse-system.md`，找到「环境事实」那一节的表格，把「本机示例」列换成你的真实路径：

| 占位符 | 你填什么 |
|---|---|
| `<TOOLROOT>` | 你的工具根目录，例 `D:\Android\tools` 或 `~/android-re/tools` |
| `<SDKROOT>` | Android SDK 根目录，例 `D:\AndroidSDK` |
| `<WORKSPACE>` | 案子根目录，例 `D:\Android\workspace` |
| `<PYTHON>` | `<TOOLROOT>/venv/bin/python`（Windows：`<TOOLROOT>\venv\Scripts\python.exe`） |
| `<JAVA_HOME>` | JDK 21 的目录 |
| `<JDK8>` | JDK 8 的目录 |
| `<KEYSTORE>` | 你的重签名证书 `.jks` |
| `<KEYSTORE_PASS>` | 证书密码 |
| `<KEY_ALIAS>` | 证书别名 |
| `<DEVICE>` | 你的测试机（只做静态可以不填） |

也可以用仓库给的模板：`cp prompts/env.example.md prompts/env.local.md`，填完对照抄进主提示词。

### 2.3 验证

```bash
# 全文搜一遍占位符，确认你该改的都改了（留着 <样本名> <案名> <pkg> 是正常的，那些是运行时变量）
grep -n "<TOOLROOT>\|<SDKROOT>\|<WORKSPACE>\|<PYTHON>\|<JAVA_HOME>" prompts/ctf-reverse-system.md | head
```

---

## 3. 装工具链

按平台选一条路线。**每条命令都有验证步骤，通过了再继续。**

### 3.1 通用部分（三个平台都一样）

#### JDK 21 + JDK 8

```bash
# 下载 Temurin（换成本机架构）
# JDK 21: https://adoptium.net/temurin/releases/?version=21
# JDK 8:  https://adoptium.net/temurin/releases/?version=8

# 解压到 <TOOLROOT>
unzip OpenJDK21U-jdk_x64_*_hotspot_*.zip -d <TOOLROOT>/jdk21
unzip OpenJDK8U-jdk_x64_*_hotspot_*.zip -d <TOOLROOT>/jdk8
```

设置 `JAVA_HOME` 指向 JDK 21（Windows 用系统环境变量，Linux/macOS 写进 `~/.bashrc` 或 `~/.zshrc`）。

**验证：**

```bash
<JAVA_HOME>/bin/java -version     # 应输出 21.x
<JDK8>/bin/java -version          # 应输出 1.8.0_xxx
```

> 为什么两个都要：Ghidra 和 jadx 要 21，老版本 apktool 和部分签名工具在 21 上会报模块错误，退回 8 就好。项目提示词里写明了切换方式。

#### Python 环境

```bash
# 需要 Python 3.10+
python3 -m venv <TOOLROOT>/venv

# 激活
source <TOOLROOT>/venv/bin/activate          # Linux / macOS
<TOOLROOT>\venv\Scripts\activate.bat         # Windows cmd
<TOOLROOT>/venv/Scripts/activate             # Windows git-bash

# 装依赖
pip install --upgrade pip
pip install androguard apkid frida-tools objection mitmproxy pycryptodome lief capstone pyelftools
```

国内加速：

```bash
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <包名>
```

**验证：**

```bash
<PYTHON> -c "import androguard, lief, capstone, Crypto; print('py ok')"
frida --version         # 应输出 17.x 或你装的版本
apkid --help            # 有输出即正常（注意：apkid 没有 --version 参数）
objection version
mitmdump --version
```

#### apktool

```bash
# 下 apktool 最新 jar + 对应的 wrapper 脚本
# https://github.com/iBotPeaches/Apktool/releases
mkdir -p <TOOLROOT>/apktool
# 把 apktool_x.x.x.jar 放进去，命名为 apktool.jar
# 把 apktool.bat / apktool（shell 版）也放进去
```

**验证：**

```bash
apktool --version
```

> 坑：`apktool b` 报 `AndrolibException` 是缺框架资源，先 `apktool if framework-res.apk`。

#### jadx（只用 CLI，不要 GUI）

```bash
# https://github.com/skylot/jadx/releases
unzip jadx-1.5.6.zip -d <TOOLROOT>/jadx-1.5.6
```

**验证：**

```bash
<TOOLROOT>/jadx-1.5.6/bin/jadx --version     # 应输出 1.5.6
```

> 项目明确要求只使用 CLI，不要用 jadx-gui —— 提示词里写死了这一条。

#### DexSQL（SQL 直查 dex，定位首选）

```bash
# https://github.com/LSPosed/dexsql-release/releases
# 下载 dexsql-windows-amd64.exe（或对应平台），重命名 dexsql.exe
mkdir -p <TOOLROOT>/DexSQL
# 放进去，LICENSE / SHA256SUMS 一起带上
```

**验证：**

```bash
<TOOLROOT>/DexSQL/dexsql.exe --version                              # dexsql 0.1.1
<TOOLROOT>/DexSQL/dexsql.exe query --input app.apk --sql "SELECT count(*) FROM methods"
```

> 它只做 SQL 查询和 smali 反汇编，**不做 Java 反编译**。dex → Java 还是 jadx。

#### dex-tools

```bash
# https://github.com/pxb1988/dex2jar/releases
unzip dex-tools-2.4.zip -d <TOOLROOT>/dex-tools
```

**验证：**

```bash
<TOOLROOT>/dex-tools/d2j-dex2jar.sh --help     # Windows 用 .bat
```

#### radare2

```bash
# https://github.com/radareorg/radare2/releases
# Windows 下载 radare2-x.x.x-w64.zip，解压到 <TOOLROOT>/radare2
```

**验证：**

```bash
r2 -v
# Windows git-bash 里如果 command not found，改用 r2.bat
```

#### Ghidra

```bash
# https://github.com/NationalSecurityAgency/ghidra/releases
unzip ghidra_*.zip -d <TOOLROOT>/ghidra
```

**验证：**

```bash
<TOOLROOT>/ghidra/ghidra_*/support/analyzeHeadless -h
```

#### unidbg

```bash
# 自己建一个 Maven 工程依赖 unidbg-android，打出来的 jar 放 <TOOLROOT>/unidbg
```

**验证：**

```bash
ls <TOOLROOT>/unidbg/*.jar
```

#### 签名证书

```bash
keytool -genkeypair -v \
  -keystore <KEYSTORE> \
  -alias <KEY_ALIAS> \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass <KEYSTORE_PASS> -keypass <KEYSTORE_PASS> \
  -dname "CN=CTF Lab"
```

**验证：**

```bash
keytool -list -keystore <KEYSTORE> -storepass <KEYSTORE_PASS>
```

#### frida-server

```bash
# 只在真机档需要。版本必须与 frida 客户端严格一致
# https://github.com/frida/frida/releases
# 下 frida-server-<版本>-android-arm64.xz，解压后放 <TOOLROOT>/frida/
```

**验证：**

```bash
frida --version
ls <TOOLROOT>/frida/frida-server-*-android-arm64
```

> 真机是 arm64-v8a，别下 x86_64 那份。

### 3.2 共用脚本

项目提示词引用了三个脚本，放 `<TOOLROOT>/scripts/`：

| 脚本 | 作用 | 来源 |
|---|---|---|
| `ssl-unpinning.js` | 多层 SSL Pinning 绕过 | 自写 / 参考 frida-codeshare 的通用 unpinning 模板 |
| `root-bypass.js` | root / 调试 / frida 痕迹隐藏 | 自写 |
| `r0capture.py` | 全量流量抓取（含 TLS 明文） | https://github.com/r0ysue/r0capture |

```bash
mkdir -p <TOOLROOT>/scripts
cd <TOOLROOT>/scripts
git clone https://github.com/r0ysue/r0capture.git tmp-r0
cp tmp-r0/r0capture.py . && rm -rf tmp-r0
# ssl-unpinning.js / root-bypass.js 自己按需写，或先放空文件占位
```

**验证：**

```bash
ls <TOOLROOT>/scripts/
```

### 3.3 Android SDK（命令行工具就够，不用 Studio）

```bash
mkdir -p <SDKROOT>/cmdline-tools
# 下载 commandlinetools: https://developer.android.com/studio#command-tools
unzip commandlinetools-*.zip -d <SDKROOT>/cmdline-tools
mv <SDKROOT>/cmdline-tools/cmdline-tools <SDKROOT>/cmdline-tools/latest

export ANDROID_HOME=<SDKROOT>
export PATH=$PATH:<SDKROOT>/cmdline-tools/latest/bin:<SDKROOT>/platform-tools

sdkmanager --install "platform-tools" "build-tools;36.0.0" "platforms;android-35"
```

**验证：**

```bash
adb version
aapt2 version
apksigner --version
zipalign -h | head -3
```

> 坑：`sdkmanager` 报 "Java version 17 or higher is required" 是版本号解析 bug。设 `SKIP_JDK_VERSION_CHECK=1`，或确认 `JAVA_HOME` 指向 JDK 21。

### 3.4 Windows 特有

把下面这些目录加进用户 `PATH`（或用项目里的 `set_path` 思路自己写个脚本）：

```
<SDKROOT>\platform-tools
<SDKROOT>\build-tools\36.0.0
<SDKROOT>\cmdline-tools\latest\bin
<TOOLROOT>\apktool
<TOOLROOT>\dex-tools
<TOOLROOT>\jadx-1.5.6\bin
<TOOLROOT>\frida
<TOOLROOT>\scripts
<TOOLROOT>\signer
<TOOLROOT>\java-decompiler
<TOOLROOT>\radare2\radare2-*-w64\bin
<TOOLROOT>\ghidra\ghidra_*\support
<TOOLROOT>\jdk21\*\bin
<TOOLROOT>\venv\Scripts
```

**开新终端后验证：**

```powershell
$env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
foreach ($c in 'frida','jadx','apktool','apkid','r2','apksigner','adb','python') {
  $x = Get-Command $c -ErrorAction SilentlyContinue
  if ($x) { Write-Host "$c -> $($x.Source)" } else { Write-Host "$c -> MISSING" }
}
```

全部命中就 OK。

> **git-bash 坑**：MSYS 路径转换默认是关的。给 Java / 原生程序传路径要写 `D:/cases/x.apk`，不能写 `/d/cases/x.apk`，否则报 `Input file was not found`。

### 3.5 国内网络加速

| 目标 | 做法 |
|---|---|
| GitHub Releases | `https://gh-proxy.com/<原始链接>` 前置代理 |
| PyPI | `-i https://pypi.tuna.tsinghua.edu.cn/simple` |
| Google SDK 组件 | `dl.google.com` 直连通常可用，慢的话多试几次或换时段 |
| 大文件下不动 | **别硬等**，直接把链接抄下来手动下，下好放进对应目录 |

---

## 4. 初始化工作区

```bash
# 把项目里的脚手架复制到你的工作区
mkdir -p <WORKSPACE>
cp -r android-ctf-re-agent/workspace/* <WORKSPACE>/

# 给脚本执行权限（Linux / macOS / git-bash）
chmod +x <WORKSPACE>/new_case.sh
```

**验证：**

```bash
ls <WORKSPACE>
# 应看到：new_case.sh  new_case.ps1  _report-template.md  _crackme-template.md  scripts/
```

### 4.1 改脚本里的路径

`new_case.sh` 会优先读环境变量 `WORKSPACE`，没设就用脚本所在目录。想固定到别处：

```bash
export WORKSPACE=/your/path/workspace
```

或直接改脚本顶部的 `ROOT="${WORKSPACE:-$SCRIPT_DIR}"` 这一行为绝对路径。

Windows 用 `new_case.ps1`，逻辑一样。

**验证：**

```bash
grep -n 'ROOT=' <WORKSPACE>/new_case.sh
```

---

## 5. 跑通第一条命令（冒烟测试）

拿任意一个小 APK（自己编一个也行，见 §5.1），跑一次开案：

```bash
bash <WORKSPACE>/new_case.sh <你的样本.apk> smoke-test analyze
```

**期望输出：**

```
开案完成（模式: analyze）
  目录  : <WORKSPACE>/smoke-test
  样本  : <WORKSPACE>/smoke-test/original.apk
  sha256: <一串hash>
  大小  : <字节数> bytes
  报告  : <WORKSPACE>/smoke-test/report.md
```

**然后检查目录：**

```bash
ls <WORKSPACE>/smoke-test
# 应看到：apktool case.json dump native original.apk raw report.md resources scripts sources
# （analyze 模式没有 build/ patch/ test/，crack 模式才有）
```

再看 `case.json` 里的路径对不对：

```bash
cat <WORKSPACE>/smoke-test/case.json
```

能读到 `"mode": "analyze"` 和正确的 `sha256` 就算通了。

**清理：**

```bash
rm -rf <WORKSPACE>/smoke-test
```

### 5.1 没有样本？自己编一个

```bash
# 随便抓一个 <10MB 的开源 apk 当练手目标；或者用一个空文件也能验证脚本流程
head -c 2048 /dev/urandom > /tmp/FakeTest.apk
bash <WORKSPACE>/new_case.sh /tmp/FakeTest.apk smoke-test analyze
```

空文件也能跑通开案流程（只是后续分析没内容），用来验证脚手架是否正常足够了。

### 5.2 CrackMe 模式也测一遍

```bash
bash <WORKSPACE>/new_case.sh /tmp/FakeTest.apk smoke-crack crack
ls <WORKSPACE>/smoke-crack
# 这次应该多出 build/ patch/ test/ 三个目录，report.md 是八章骨架
rm -rf <WORKSPACE>/smoke-crack /tmp/FakeTest.apk
```

---

## 6. 接上你的 Agent

### 6.1 通用做法

1. 打开 `prompts/ctf-reverse-system.md`
2. **整份文件全文复制**，作为系统提示词 / 项目规则 / 第一条消息喂给 agent
3. 确认 agent 已读到全文（不是摘要）
4. 发激活词

### 6.2 各平台位置

| Agent | 放哪 |
|---|---|
| Claude Code | 项目根放 `CLAUDE.md`，内容为提示词全文；或启动后用 `/memory` 导入 |
| Codex CLI | 项目根放 `AGENTS.md` |
| OpenCode | 项目根放 `AGENTS.md` 或 `.opencode/rules.md` |
| Cursor | `.cursorrules`（旧版）或 `.cursor/rules/*.mdc` |
| Hermes | 会话内直接粘贴，或做成 skill |
| 网页版模型 | 直接贴第一条消息 |

**不管放哪，都要包含路径表那一段**，否则 agent 不知道 `<TOOLROOT>` 是什么。

### 6.3 验证 agent 接对了

发：

```
bushi
```

**正确反应**（一字不差）：

```
我准备好了，请发我apk
```

如果它开始讲计划、问你要分析什么、或者列一堆注意事项 —— 说明提示词没喂进去或没读完，重来一次。

---

## 7. 常见问题

| 现象 | 原因 / 解法 |
|---|---|
| `Input file was not found` | git-bash 把 `/d/...` 原样给了原生 exe。改写 `D:/...` |
| `r2: command not found` | Windows 只提供 `r2.bat`，bash 里写 `r2.bat` |
| `sdkmanager` 报 Java 版本不对 | 设 `SKIP_JDK_VERSION_CHECK=1` 或用 JDK 21 |
| frida `unable to connect` | 客户端与 frida-server 版本必须严格一致 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 签名变了。`adb uninstall <pkg>` 再装 |
| `apktool b` 抛 `AndrolibException` | 缺框架资源，先 `apktool if framework-res.apk` |
| jadx 出一堆 `// error` | 加 `--show-bad-code`，不行换 CFR 兜底 |
| `.ps1` 带中文报 `UnexpectedToken` | PowerShell 5.1 按 ANSI 读 UTF-8。脚本正文写纯 ASCII |
| GitHub 下载 74 KB/s | 套 `https://gh-proxy.com/<原始链接>` |
| 改了 smali 但行为没变 | 改的不是被编译的那份 smali 目录，或多 dex 没同步 |
| dexsql 报 `unknown column` | 列名不是直觉名：`methods` 用 `name`/`class_descriptor`/`descriptor`；调用图在 `method_calls`。先 `dexsql tables` 核对 |
| 重签后闪退白屏 | 反篡改。按提示词「阶段 C2 加载失败回查顺序」八步走 |

更多见 [`docs/faq.md`](docs/faq.md)。

---

## 8. 下一步

- 想懂方法论 → [`docs/crackme-playbook.md`](docs/crackme-playbook.md)
- 想查检测点 → [`docs/anti-tamper-checklist.md`](docs/anti-tamper-checklist.md)
- 想补工具细节 → [`docs/setup-toolchain.md`](docs/setup-toolchain.md)
- 想精简提示词 → [`prompts/ctf-reverse-system.lite.md`](prompts/ctf-reverse-system.lite.md)
- 想看完整流程演示 → [`examples/README.md`](examples/README.md)

---

## 检查清单（全部打勾才算搭好）

- [ ] `git clone` 成功，目录结构完整
- [ ] `<TOOLROOT>` `<SDKROOT>` `<WORKSPACE>` 三个路径定了
- [ ] 主提示词里的占位符表已替换成自己的路径
- [ ] JDK 21 和 JDK 8 都能跑 `-version`
- [ ] Python 环境 `import androguard` 成功
- [ ] `frida --version` / `apkid --help` / `objection version` 有输出
- [ ] `jadx --version` 输出 1.5.6
- [ ] `apktool --version` 有输出
- [ ] `adb` / `aapt2` / `apksigner` / `zipalign` 都能跑
- [ ] `<KEYSTORE>` 建好，`keytool -list` 能读
- [ ] 工作区脚手架已复制，`new_case.sh` 可执行
- [ ] 冒烟测试跑通，`case.json` 内容正确
- [ ] crack 模式也跑通，多出 `build/ patch/ test/`
- [ ] 提示词已喂给 agent，发 `bushi` 得到「我准备好了，请发我apk」
