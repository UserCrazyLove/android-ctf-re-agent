# 从零搭建工具链

本文按「装完就能用」的顺序排列，每个工具都配验证命令。装完一个验一个，失败别往下走。

> 全部路径用占位符：`<TOOLROOT>` 工具根、`<SDKROOT>` SDK 根、`<WORKSPACE>` 工作区。填法见 `prompts/env.example.md`。

---

## 0. 总览

| 层 | 组件 | 必需 |
|---|---|---|
| 运行时 | JDK 21、JDK 8、Python 3.10+ venv | 是 |
| 解包反编译 | apktool、jadx CLI、dex-tools、CFR | 是 |
| 静态分析 | apkid、apkInspector、androguard、**DexSQL**、rabin2、Ghidra | 是 |
| 二进制处理 | radare2、LIEF、capstone、pyelftools | 是 |
| 签名 | apksigner、zipalign、keytool、uber-apk-signer | 是 |
| 无设备执行 | unidbg | 是 |
| 动态（真机才用） | frida、frida-tools、objection、frida-dexdump、mitmproxy、r0capture | 按需 |
| SDK | platform-tools、build-tools、platforms | 是 |

---

## 1. 运行时

### JDK 21（主力）

```bash
# https://adoptium.net/temurin/releases/?version=21
unzip OpenJDK21U-jdk_x64_windows_hotspot_*.zip -d <TOOLROOT>/jdk21
export JAVA_HOME=<TOOLROOT>/jdk21/jdk-21.0.12.1+1
export PATH=$JAVA_HOME/bin:$PATH
java -version    # 期望：openjdk version "21.x"
```

### JDK 8（老工具用）

```bash
unzip OpenJDK8U-jdk_x64_windows_hotspot_*.zip -d <TOOLROOT>/jdk8
<TOOLROOT>/jdk8/bin/java -version    # 期望：1.8.0_xxx
```

切换方式：临时 `export JAVA_HOME=<JDK8>`，或 Windows `set JAVA_HOME=...`。

> **为什么两个都要**：Ghidra 12 和 jadx 要 21；部分老 apktool 版本和签名工具在 21 上会报模块错误，退回 8 就好。

### Python venv

```bash
python3 -m venv <TOOLROOT>/venv
source <TOOLROOT>/venv/bin/activate        # Linux/macOS
# <TOOLROOT>\venv\Scripts\activate         # Windows

pip install -U pip
pip install androguard apkid frida-tools objection mitmproxy \
            pycryptodome lief capstone pyelftools ipython
```

国内加速：`-i https://pypi.tuna.tsinghua.edu.cn/simple`

```bash
<PYTHON> -c "import androguard, lief, capstone, Crypto; print('ok')"
```

> **坑**：`python -m venv /d/x` 在 git-bash 里会建出缺 `Scripts\python.exe` 的坏环境。先 `cd` 到父目录再用相对名 `python -m venv venv`。

---

## 2. 解包与反编译

### apktool

```bash
mkdir -p <TOOLROOT>/apktool
# https://github.com/iBotPeaches/Apktool/releases
# 放 apktool_x.x.x.jar → <TOOLROOT>/apktool/apktool.jar
# 放 apktool.bat（Windows）/ apktool（shell）→ 同目录
apktool --version
```

常见错误：

| 报错 | 原因 | 解 |
|---|---|---|
| `AndrolibException: Could not decode arsc` | 缺框架资源 | `apktool if framework-res.apk` |
| 回编后 so 丢失 | `apktool.yml` 里 `doNotCompress` 配置问题 | 手动解压原 apk 的 `lib/` 补回去 |

### jadx（只用 CLI）

```bash
# https://github.com/skylot/jadx/releases
unzip jadx-1.5.6.zip -d <TOOLROOT>/jadx-1.5.6
<TOOLROOT>/jadx-1.5.6/bin/jadx --version   # 期望 1.5.6
```

本项目**只使用 CLI**，不使用 jadx-gui。常用参数：

```bash
jadx -d out --show-bad-code --no-res app.apk    # 只要代码
jadx -d out app.apk                             # 代码 + 资源
```

### dex-tools

```bash
# https://github.com/pxb1988/dex2jar/releases
unzip dex-tools-2.4.zip -d <TOOLROOT>/dex-tools
<TOOLROOT>/dex-tools/d2j-dex2jar.sh --help
```

Windows 下对应 `.bat`。注意：**没有独立的 `baksmali` / `smali` 命令**，前缀是 `d2j-`。

### DexSQL（SQL 直查 dex，定位首选）

```bash
# https://github.com/LSPosed/dexsql-release/releases
# 下载 dexsql-windows-amd64.exe（或对应平台），重命名为 dexsql.exe
mkdir -p <TOOLROOT>/DexSQL
# 放到 <TOOLROOT>/DexSQL/dexsql.exe，顺手把 LICENSE / SHA256SUMS 一起放进去
```

**验证：**

```bash
<TOOLROOT>/DexSQL/dexsql.exe --version      # 期望 dexsql 0.1.1
<TOOLROOT>/DexSQL/dexsql.exe query --input app.apk --sql "SELECT count(*) FROM methods"
```

**能力边界**：只做 SQL 查询和 smali 反汇编，**不做 Java 反编译**。dex → Java 仍然用 jadx。

**列名坑**：`methods` 表里是 `name` / `class_descriptor` / `descriptor`，不是 `method_name` / `class_name`；调用图在 `method_calls`（`method_name` / `callee_name`）。写错会报 `unknown column`，先 `dexsql tables --input x.apk` 核对。

常用查询见 [crackme-playbook.md](crackme-playbook.md) 和 [anti-tamper-checklist.md](anti-tamper-checklist.md)。

### CFR（jadx 失败时兜底）

```bash
mkdir -p <TOOLROOT>/java-decompiler
# https://github.com/leibnitz27/cfr/releases
# 放 cfr-0.152.jar → <TOOLROOT>/java-decompiler/
java -jar <TOOLROOT>/java-decompiler/cfr-0.152.jar --help
```

---

## 3. 静态分析

### apkid / apkInspector / androguard

三个都在 `<PYTHON>` 环境里，pip 装完就有。

```bash
apkid app.apk                  # 判壳，注意没有 --version
apkInspector -apk app.apk -m   # 解 manifest；-la 列全部 zip 条目；-ll 只看 local header
androguard analyze app.apk     # 起 IPython 交互
```

### rabin2 / radare2

```bash
# https://github.com/radareorg/radare2/releases
# Windows 下 radare2-x.x.x-w64.zip → <TOOLROOT>/radare2/
rabin2 -I libx.so     # 架构与保护
rabin2 -zz libx.so    # 字符串
rabin2 -E libx.so     # 导出表
r2 -A libx.so
```

> Windows git-bash 里 `r2` 找不到就写 `r2.bat`。

### Ghidra

```bash
# https://github.com/NationalSecurityAgency/ghidra/releases
unzip ghidra_12.2_PUBLIC_*.zip -d <TOOLROOT>/ghidra
<TOOLROOT>/ghidra/ghidra_12.2_PUBLIC/support/analyzeHeadless -h
```

无头批处理：

```bash
analyzeHeadless <projdir> <projname> -import libx.so \
  -postScript DecompileAll.java -scriptPath <scripts>
```

---

## 4. 二进制处理库

pip 已装：`lief`、`capstone`、`pyelftools`、`pycryptodome`。

```bash
<PYTHON> -c "import lief; print(lief.__version__)"
<PYTHON> -c "import capstone; print(capstone.__version__)"
```

用途：

- `lief` —— 改 so 段属性、导出表、重算校验和
- `capstone` —— 反汇编引擎，写脚本批量找指令模式
- `pycryptodome` —— 还原算法后做对拍

---

## 5. 签名

### 生成自己的证书

```bash
keytool -genkeypair -v \
  -keystore <KEYSTORE> -alias <KEY_ALIAS> \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass <KEYSTORE_PASS> -keypass <KEYSTORE_PASS> \
  -dname "CN=CTF Lab"
keytool -list -keystore <KEYSTORE> -storepass <KEYSTORE_PASS>
```

### apksigner + zipalign

SDK build-tools 自带。

```bash
zipalign -p -f 4 unsigned.apk aligned.apk
apksigner sign --ks <KEYSTORE> --ks-pass pass:<KEYSTORE_PASS> \
  --key-pass pass:<KEYSTORE_PASS> --ks-key-alias <KEY_ALIAS> \
  --out signed.apk aligned.apk
apksigner verify --print-certs signed.apk
```

**顺序不能反**：先 sign 后 align 会破坏签名。

### uber-apk-signer（批量）

```bash
# https://github.com/patrickfav/uber-apk-signer/releases
java -jar <TOOLROOT>/signer/uber-apk-signer-1.3.0.jar -a out/
```

---

## 6. unidbg（无设备跑 so）

```bash
# https://github.com/zhklilu/unidbg-fetch-qsign 之类示例工程，或用 Maven 自建
# 产出 unidbg-android-x.x.x.jar → <TOOLROOT>/unidbg/
```

写一个 Java main：

```java
AndroidEmulator emulator = new AndroidEmulator(new File("target/"), false, new DvmResolver("unidbg-android-0.9.9.jar"));
DalvikModule dm = new DalvikModule(emulator, "libx.so");
dm.callJNI_OnLoad(emulator);
// 通过 JNIEnv 调目标方法，打印输入输出
```

这是**不需要真机**还原 so 算法的主力手段。

---

## 7. 动态工具（真机档才用）

只在提示词「第二档」触发、且用户明确同意后使用。装好放着即可。

### frida + frida-tools

```bash
pip install frida-tools    # 已在 venv 里
frida --version
```

### frida-server（设备端）

```bash
# https://github.com/frida/frida/releases
# 版本必须与客户端严格一致
# frida-server-17.24.3-android-arm64.xz → 解压 → <TOOLROOT>/frida/
ls <TOOLROOT>/frida/frida-server-*-android-arm64
```

> 真机是 arm64-v8a；推错架构会 `unable to connect` 或 `exec format error`。

### objection

```bash
pip install objection
objection version
```

### frida-dexdump / wallbreaker

```bash
pip install frida-dexdump
pip install wallbreaker    # objection 插件
```

### mitmproxy

```bash
mitmdump --version
# 证书：~/.mitmproxy/mitmproxy-ca-cert.cer
```

### r0capture

```bash
git clone https://github.com/r0ysue/r0capture.git
cp r0capture/r0capture.py <TOOLROOT>/scripts/
```

---

## 8. Android SDK

```bash
mkdir -p <SDKROOT>/cmdline-tools
# https://developer.android.com/studio#command-tools
unzip commandlinetools-*.zip -d <SDKROOT>/cmdline-tools
mv <SDKROOT>/cmdline-tools/cmdline-tools <SDKROOT>/cmdline-tools/latest

export ANDROID_HOME=<SDKROOT>
export PATH=$PATH:<SDKROOT>/cmdline-tools/latest/bin:<SDKROOT>/platform-tools

sdkmanager --install "platform-tools" "build-tools;36.0.0" "platforms;android-35"
adb version
aapt2 version
```

> 报 "Java version 17 or higher is required"：设 `SKIP_JDK_VERSION_CHECK=1`，或确认 `JAVA_HOME` 指向 JDK 21。

---

## 9. PATH 汇总

装完后下面这些目录都要在 PATH 里：

```
<SDKROOT>/platform-tools
<SDKROOT>/build-tools/36.0.0
<SDKROOT>/cmdline-tools/latest/bin
<TOOLROOT>/apktool
<TOOLROOT>/dex-tools
<TOOLROOT>/jadx-1.5.6/bin
<TOOLROOT>/frida
<TOOLROOT>/scripts
<TOOLROOT>/signer
<TOOLROOT>/java-decompiler
<TOOLROOT>/DexSQL
<TOOLROOT>/radare2/radare2-*-w64/bin
<TOOLROOT>/ghidra/ghidra_*/support
<TOOLROOT>/jdk21/*/bin
<TOOLROOT>/venv/Scripts          (Windows)
<TOOLROOT>/venv/bin              (Linux/macOS)
```

### 一键自检

```bash
for c in java javac python pip apktool jadx apkid apkInspector dexsql r2 rabin2 \
         frida objection frida-dexdump mitmdump keytool adb aapt2 apksigner zipalign; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '%-16s OK   %s\n' "$c" "$(command -v "$c")"
  else
    printf '%-16s MISSING\n' "$c"
  fi
done
```

Windows PowerShell：

```powershell
$env:PATH = [Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH','User')
foreach ($c in 'java','python','apktool','jadx','apkid','r2','frida','objection','adb','aapt2','apksigner','zipalign') {
  $x = Get-Command $c -ErrorAction SilentlyContinue
  if ($x) { Write-Host ("{0,-16} OK   {1}" -f $c, $x.Source) } else { Write-Host ("{0,-16} MISSING" -f $c) }
}
```

全部 OK 才算搭完。

---

## 10. 版本对照（建议组合，实测可跑）

| 组件 | 版本 |
|---|---|
| JDK | 21.0.12 / 8u504 |
| Python | 3.13 |
| apktool | 3.0.3 |
| jadx | 1.5.6 |
| DexSQL | 0.1.1 |
| dex-tools | 2.4.x |
| CFR | 0.152 |
| frida / frida-tools / frida-server | 17.24.3 / 14.11.0 / **17.24.3（三者一致）** |
| objection | 1.12.5 |
| wallbreaker | 1.0.3 |
| frida-dexdump | 2.0.1 |
| mitmproxy | 12.3.0 |
| Ghidra | 12.2 |
| radare2 | 6.2.4 |
| APKiD | 3.2.0 |
| androguard | 4.1.4 |
| apkInspector | 1.3.7 |
| LIEF | 1.0.0 |
| capstone | 5.0.9 |
| unidbg | 0.9.9 |
| build-tools | 36.0.0 |
| platform-tools | 37.0.1 |
| NDK（需要时） | 29.x |
