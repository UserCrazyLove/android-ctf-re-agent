# FAQ — 常见卡点与报错

---

## 一、环境与工具

### Q: `jadx` 或 `apktool` 报 `Input file was not found`，但文件明明在

git-bash 下 `/d/cases/x.apk` 这种路径被原样传给原生 exe，Windows 程序看不懂。

**解法**：给 Java / 原生工具传路径一律写 `D:/cases/x.apk`（正斜杠的盘符路径）。

---

### Q: `r2: command not found`

Windows 版 radare2 只提供 `radare2.exe` 和 `r2.bat`。

**解法**：bash 里写 `r2.bat`。

---

### Q: `sdkmanager` 报 `Java version 17 or higher is required`

JDK 版本号解析 bug（有的 JDK 版本串是纯数字 `27`，检查器要 `x.y` 形态）。

**解法**：
```bash
export SKIP_JDK_VERSION_CHECK=1
```
或确认 `JAVA_HOME` 指向 JDK 21。

---

### Q: frida 报 `unable to connect`

客户端和 server 版本不一致，或 server 没跑起来，或架构推错。

**排查**：
```bash
frida --version                      # 客户端版本
adb shell /data/local/tmp/frida-server --version   # server 版本
```
两者必须**完全一致**。真机是 arm64-v8a，别推 x86_64。

---

### Q: `apkid --version` 报 unrecognized

APKiD 没有 `--version` 参数。

**解法**：直接 `apkid app.apk`。

---

### Q: `.ps1` 脚本报 `UnexpectedToken`

PowerShell 5.1 按 ANSI 读 UTF-8 文件，中文注释会破坏解析。

**解法**：脚本正文写纯 ASCII / 英文注释；或存成 UTF-8 with BOM。

---

### Q: 下载速度只有几十 KB/s

**解法**：GitHub 加代理前缀 `https://gh-proxy.com/<原始链接>`；PyPI 用 `-i https://pypi.tuna.tsinghua.edu.cn/simple`。

**如果还是慢**：别硬等，把链接抄下来手动下，下好放进对应目录。

---

## 二、解包与反编译

### Q: `jadx -d` 输出一堆 `// error`

**解法**：加 `--show-bad-code` 保留伪代码；仍失败换 CFR 兜底：
```bash
java -jar <TOOLROOT>/java-decompiler/cfr-0.152.jar classes.jar --outputdir src
```

---

### Q: `apktool b` 抛 `AndrolibException`

缺框架资源。

**解法**：
```bash
apktool if framework-res.apk
```
框架文件从任一台同版本设备的 `/system/framework/framework-res.apk` 提取，或从网上下对应 Android 版本的。

---

### Q: 修改了 smali 但回编后行为没变

改的不是被编译的那份。

**排查**：
```bash
grep -n "dex" apktool/apktool.yml     # 看有几个 dex
ls apktool/smali*/                    # 看有几个 smali 目录
```
多 dex 时 `smali/`、`smali_classes2/`、`smali_classes3/` 都要改对应的那一份。另外注意有没有 `smali_plain/` 之类的额外目录。

---

### Q: 回编后 so 丢失或架构不全

`apktool.yml` 里 `doNotCompress` 与 `lib/` 处理有问题，或 so 被当成普通资源压缩了。

**排查**：
```bash
unzip -l build/unsigned.apk | grep lib/
```

**修法**：从原 apk 里解出 `lib/`，回编后手动塞进 zip 对应位置。

---

## 三、签名与安装

### Q: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

签名与原包不同（重签必然不同）。

**解法**：
```bash
adb uninstall <pkg>
adb install build/cracked.apk
```
要保留数据：`adb install -r -d build/cracked.apk`，但证书必须一致。

---

### Q: 签名后装上了但闪退

九成是反篡改检测。

**排查顺序**：见提示词「阶段 C2 加载失败回查顺序」八步。

---

### Q: 先签名再 zipalign 可以吗

不可以。**先 `zipalign` 后 `apksigner sign`**，顺序反了签名会失效。

---

### Q: `apksigner verify` 报 `DOES NOT VERIFY`

签名过程中被破坏。常见原因：
- 先签后 align
- 用 apktool 重新打包覆盖了签名后的文件
- 签名参数（alias / 密码）不对

**重来一次**，严格按顺序。

---

## 四、动态分析

### Q: 我能连手机，为什么 agent 不直接用

这是设计。设备使用分两级：

1. 纯静态（默认，绝大多数活在这层干完）
2. 真机（静态确实做不到才用，且必须先告知、等用户点头、每步单独请求）

`adb devices` 里有设备**不代表**授权使用。提示词里写死了这条。

---

### Q: 模拟器为什么不用

x86_64 模拟器需要硬件加速（AEHD / WHPX），多数机器没装；就算跑起来，结果也不代表真实设备，结论不可信。

**直接用静态分析，必要时申请真机。**

---

### Q: frida 一启动 App 就闪退

App 有反 Frida 检测。

**尝试**：
```bash
frida -U -f <pkg> -l <TOOLROOT>/scripts/root-bypass.js --no-pause
```
或换改名版 server（strongR-frida / hluda）。仍不行就静态定位检测点后 patch。

---

### Q: 抓不到包 / 全是乱码

SSL Pinning 或自定义加密。

**尝试**：
1. `mitmdump -p 8080 -w cap.mitm` + `ssl-unpinning.js`
2. 仍不行用 `r0capture.py`（hook `SSL_write` / `SSL_read`，直接拿明文）
3. 还是不行说明是自定义协议加密，回去静态找加解密函数

---

## 五、CrackMe 破解

### Q: 改完显示"已解锁"但功能用不了

典型"假成功"。UI 判断改过了，功能实际调用处还有一次检查。

**解法**：追功能真正的执行方法（不是 UI 判断），再改一次。必须逐项点功能走到实际产出才算过。

---

### Q: 改完装不上/闪退/白屏

别改业务代码，先查检测点。按「阶段 C2 加载失败回查顺序」八步走。

---

### Q: `VerifyError`

smali 寄存器类型不匹配。常见错误：

- 返回 `long` 用了 `const/4` 而不是 `const-wide`
- 返回 `boolean` 用了 `const/4 v0, 0x1` 但方法签名是 `int`
- 对象返回用 `const` 常量

**检查**：方法的返回类型 + 指令类型是否匹配。

---

### Q: `UnsatisfiedLinkError`

so 没加载成功。原因：
- 回编后 `lib/` 丢了
- so 被压缩破坏了
- 架构不匹配（设备 arm64，包里只有 armeabi）

**排查**：`unzip -l` 看 `lib/`，`file libxxx.so` 看架构。

---

### Q: 断网就废了

本地化没做透。

**排查**：搜 `isConnected`、`getActiveNetwork`、`NetworkCapabilities`，把联网判定改成本地通过；仍有服务端数据依赖的，本地 mock 或内置缓存。

**做不到就如实写进「残留问题」**，不要假装离线可用。

---

### Q: 怎么判断改对了

三个标准：

1. 冷启动直达主界面，无任何弹窗
2. 每个目标功能都能走到实际产出（不是只打开界面）
3. 断网、改时间、清数据后重进，状态仍然正常

---

## 六、Agent 使用

### Q: 发 `bushi` 后 agent 开始讲计划，没回"我准备好了"

提示词没喂进去，或没被读完整。

**检查**：
1. 确认整份 `ctf-reverse-system.md` 全文都给了 agent（不是摘要）
2. 确认路径表那一段也在里面
3. 重开会话再试

---

### Q: agent 自己装了 apk 还去点功能

这是硬违规。提示词里写死：Crack 完只交付 apk 路径，装包和试用交给用户。

**如果发生了**：直接指出，让它停下来，把路径给你就行。

---

### Q: agent 想连手机

它应该先说要干什么、卡在哪，然后等你说"开始"。

**如果它直接连了**：这是跳过了第二档流程，提示它看「工作模式」那节。

---

### Q: agent 报告写得很长但没有证据编号

违规。硬约束第 1 条要求每条结论有 Evidence 编号，没有证据的推断必须标 `confidence: low` 并进「遗留问题」。

**让它重写**，或直接指出缺哪条证据。

---

## 七、工作区

### Q: 多个样本会不会串

不会。一案一目录，每个 APK 独占 `<WORKSPACE>/<案名>/`，产物不出目录。

重名时脚本自动加 `_YYYYMMDD_HHMMSS` 后缀。

---

### Q: `new_case.sh` 报"缺模板"

模板文件（`_report-template.md` / `_crackme-template.md`）必须和脚本在同一目录。

**检查**：
```bash
ls <WORKSPACE>
# 应该有 new_case.sh  _report-template.md  _crackme-template.md  scripts/
```

---

### Q: 想换工作区位置

改 `new_case.sh` 顶部的 `ROOT="..."`，或设环境变量：
```bash
export WORKSPACE=/new/path/workspace
```
脚本优先读环境变量。

---

### Q: `case.json` 里的 `device` 是 `<DEVICE>`

占位符没替换。只做静态分析时可以不管；要用真机时再填。
