# 反篡改 / 反分析检测点全表

CrackMe 破解时最大的一类翻车是"改完加载不了"。这份表按类别列出常见检测点、识别特征、处理方式，可以当 checklist 逐项排查。

> 用法：拿到样本后，用这张表的「识别特征」列去反编译产物里搜，命中就标记，改完打勾。

---

## A. 反分析（Anti-Analysis）

### A1 调试器检测

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| `ptrace` 自陷 | native 层调用 `ptrace(PTRACE_TRACEME, ...)` | patch so 返回值，或 hook `ptrace` |
| TracerPid | 读 `/proc/self/status` 的 `TracerPid` 字段 | hook 读取函数，返回 0 |
| `Debug.isDebuggerConnected()` | Java 直接调用 | 让方法恒返回 false |
| `waitForDebugger` | `Debug.waitForDebugger()` | 删掉调用 |
| JDWP 端口 | 检测 8700 端口 / `android:debuggable` | 改 manifest 或 hook |
| 时间差检测 | `SystemClock.elapsedRealtime()` 前后差值异常 | 干扰计时或跳过判断 |

### A2 反 Frida

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| 默认端口 | 扫 27042 / 27043 | patch 扫描逻辑 |
| 进程名 | `frida-server` 出现在进程列表 | 改名 server（strongR-frida） |
| 内存映射 | 读 `/proc/self/maps` 找 `frida-agent`、`gum-js-loop` | hook 读取，过滤关键词 |
| 线程名 | 遍历线程找 `gum-js-loop`、`gmain` | hook `pthread_create` 或线程枚举 |
| 字符串扫描 | 扫描自身内存找 `frida` 特征串 | 用改名版 server |
| 端口扫描 | 连接 127.0.0.1:27042 | patch 连接逻辑 |

### A3 反 Xposed / LSPosed

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| 类探测 | `Class.forName("de.robv.android.xposed.XposedBridge")` | hook `Class.forName`，抛异常或返回 null |
| 方法 Hook 痕迹 | 检测方法是否被替换（native 标记） | 用 Shamiko 类模块隐藏 |
| 堆栈特征 | 异常栈里出现 Xposed 帧 | hook `getStackTrace` 过滤 |

---

## B. 反篡改（Anti-Tamper）—— 重打包必踩

### B1 签名校验

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| 签名摘要比对 | `getPackageInfo(pkg, GET_SIGNATURES)` + `MessageDigest` | 短路比对函数，或伪造返回内置正确值 |
| 证书 hash 常量 | 代码里有 32/64 位 hex 常量与签名比对 | 让比对恒真 |
| `GET_SIGNING_CERTIFICATES` | Android 9+ 新 API | 同上，注意版本分支 |
| 签名者数量 | `signatures.length` 判断 | 让条件恒过 |
| 自签名检测 | 检查是否 debug 证书 | 让判断恒假 |

### B2 完整性校验

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| dex checksum | 读 `classes.dex` 的 Adler32 / SHA-256 | 改常量或短路 |
| APK 整体 CRC | `ZipFile` + `CRC32` | 同上 |
| `resources.arsc` 校验 | 读文件算 hash | 同上 |
| assets 文件 hash | 遍历 assets 算摘要 | 同上 |
| so 段自校验 | `.text` 段 hash，`dl_iterate_phdr` 遍历 | patch so 校验函数 |
| 自身指令字节 | 读自己的 code 段比对 | patch 校验函数返回通过 |

### B3 安装环境校验

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| 安装路径 | `/data/app/~~xxx==/` 随机目录名比对 | 短路 |
| 包名比对 | `getPackageName()` 与常量比 | 一般不用改（包名不变） |
| 安装来源 | `getInstallSourceInfo` | 短路 |
| 首次安装时间 | 与预期不符则拒绝 | 短路 |

---

## C. 反运行环境（Anti-Environment）

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| su 二进制 | `File("/system/bin/su").exists()` 等路径扫描 | hook `File.exists` |
| test-keys | `Build.TAGS.contains("test-keys")` | hook 返回值 |
| Magisk 痕迹 | 检测 `/sbin/.magisk`、`magisk` 进程、`zygisk` | 用 Shamiko，或 hook |
| mount 输出 | 解析 `/proc/mounts` 找异常挂载 | hook 读取 |
| 模拟器指纹 | `goldfish`、`ranchu`、`generic`、传感器数量、CPU 型号 | hook 返回值 |
| IMEI / 设备 ID | 全 0 或异常值 | hook |
| 多开/分身 | 进程列表、容器路径、`/proc/self/maps` | hook 检测逻辑 |
| VPN / 代理 | `NetworkCapabilities` 判断、系统代理读取 | hook |
| SSL Pinning | `CertificatePinner`、自定义 `TrustManager` | 用 `ssl-unpinning.js` |

---

## D. 暗桩（Booby Traps）

这类最难，因为不像检测那样有明确特征，要靠行为和逻辑分析发现。

| 类型 | 表现 | 怎么发现 | 怎么处理 |
|---|---|---|---|
| **假成功** | 显示"已解锁"，功能仍不可用 | 逐项点功能走到实际产出 | 找真正的功能入口再改一次 |
| **延时触发** | 启动 N 秒后 / 第 3 次启动才校验 | 多次启动观察 | 找到定时器，短路判断 |
| **条件触发** | 特定机型 / 日期 / 网络状态才校验 | 改变条件观察行为 | 让条件恒不满足 |
| **错误路径埋坑** | 校验失败分支里 `System.exit` 或清数据 | 静态读失败分支 | 改对分支，或删掉破坏性调用 |
| **二次校验** | Java 过了 so 再验，或服务端再验一次 | 改完 Java 层功能仍异常 | 继续往下追 |
| **分散校验** | 一个功能一个校验点 | 改一处另一处又拦 | 做完整校验点清单，一次改完 |
| **隐写/混淆常量** | 关键值运行时解密 | 静态看不到明文 | 动态 hook 解密函数拿明文 |

---

## E. 隐藏与混淆

| 技术 | 特征 | 处理思路 |
|---|---|---|
| `DexClassLoader` | 从 assets / 网络加载第二段 dex | 追加载路径，把 dex 提出来单独反编译 |
| 字符串加密 | 常量池全是密文，运行时解密 | hook 解密函数，dump 调用结果 |
| 反射调用 | `Class.forName` + `getMethod` + `invoke` | 追反射目标，找实际方法 |
| 名校验塞在生命周期早期 | `attachBaseContext` / `ContentProvider.onCreate` | 从 Manifest 找所有自启动点，逐个看 |
| OLLVM 控制流平坦化 | so 里 switch 分发器结构 | 用 deflat 类工具，或动态 trace |
| 花指令 | 无效指令干扰反汇编 | r2 / Ghidra 手动清理 |
| VMP | 关键函数被虚拟化 | 一般放弃静态，走动态 dump |

---

## F. 时间与授权

| 检测点 | 识别特征 | 处理方式 |
|---|---|---|
| 试用期倒计时 | SP 里存首次启动时间，与当前时间比 | 改起始时间，或让判断恒过 |
| 到期日硬编码 | 常量日期字符串 | 改成远期 |
| trial 计数 | SP / DB 里计数递减 | 改成不递减，或恒大于 0 |
| `.lic` 授权文件 | 读文件 → 校验结构 → 验签 | 伪造文件，或改解析 |
| 机器码绑定 | 设备 ID → 算法 → 与授权码比 | 还原算法，本地生成 |
| 离线激活 | 输入码 → 本地算法验证 | keygen |

---

## G. 加载失败回查顺序

改完装不上 / 装上闪退 / 白屏，**严格按这个顺序查，不要盲改业务代码**：

1. **看崩溃栈**
   ```bash
   adb logcat -s AndroidRuntime:E
   ```
   先确认异常类型：`VerifyError`、`UnsatisfiedLinkError`、`SecurityException`、自定义异常

2. **签名校验**
   搜 `getPackageInfo`、`GET_SIGNATURES`、`GET_SIGNING_CERTIFICATES`、`signatures`

3. **完整性校验**
   搜 `MessageDigest`、`CRC32`、`classes.dex`、`assets/`

4. **so 加载**
   ```bash
   unzip -l build/unsigned.apk | grep lib/
   ```
   确认 `lib/arm64-v8a/` 存在且 so 完整

5. **启动即退出**
   查 `attachBaseContext`、`ContentProvider.onCreate` 里的 `System.exit`、`Process.killProcess`

6. **native crash**
   ```bash
   adb shell ls /data/tombstones/
   ```
   看 so 内偏移

7. **白屏无崩溃**
   查主题、Activity 跳转条件、启动页门禁

8. **最后才查业务 patch**
   业务改错通常表现为"功能不对"，不是"起不来"

---

## H. 排查清单（逐项打勾）

拿到一个 CrackMe 样本，按这个顺序过：

- [ ] Manifest 里所有自启动点已列出（Application / ContentProvider / Service / Receiver）
- [ ] `attachBaseContext` 里没有未处理的校验
- [ ] `ContentProvider.onCreate` 已检查
- [ ] `Application.onCreate` 已检查
- [ ] 签名校验点已定位（如有）
- [ ] 完整性校验点已定位（如有）
- [ ] root / 模拟器检测已定位（如有）
- [ ] 反调试 / 反 Frida 已定位（如有）
- [ ] 试用期 / 到期逻辑已定位（如有）
- [ ] EULA / 首启门禁已定位（如有）
- [ ] 强制更新已定位（如有）
- [ ] 付费功能入口已逐个列出
- [ ] 每个功能的实际执行方法已找到（不只是 UI 判断）
- [ ] 定时器 / 延时校验已检查
- [ ] 服务端依赖点已列出
- [ ] 所有 patch 已登记到 `patch/patch-list.md`
- [ ] 回编签名通过
- [ ] 交付给用户测试（不自己装）

---

## 附：常用搜索命令

**首选 dexsql（不用解包，毫秒级，还能看调用关系）**

```bash
cd <TOOLROOT>/DexSQL

# 签名 / 完整性检测方法
dexsql.exe query --input app.apk --sql "SELECT class_descriptor, name FROM methods WHERE lower(name) LIKE '%signature%' OR lower(name) LIKE '%integrity%' OR lower(name) LIKE '%tamper%' LIMIT 50"

# 反调试 / 反注入 / 反 root
dexsql.exe query --input app.apk --sql "SELECT class_descriptor, name FROM methods WHERE lower(name) LIKE '%debug%' OR lower(name) LIKE '%inject%' OR lower(name) LIKE '%root%' OR lower(name) LIKE '%emulator%' LIMIT 50"

# 字符串池里找特征串
dexsql.exe query --input app.apk --sql "SELECT value FROM strings WHERE value LIKE '%frida%' OR value LIKE '%xposed%' OR value LIKE '%magisk%' OR value LIKE '%su%' LIMIT 50"

# 谁调用了这些检测函数
dexsql.exe query --input app.apk --sql "SELECT method_class, method_name, callee_name FROM method_calls WHERE callee_name LIKE '%check%' OR callee_name LIKE '%verify%' LIMIT 100"

# 试用期 / 时间判定
dexsql.exe query --input app.apk --sql "SELECT class_descriptor, name FROM methods WHERE lower(name) LIKE '%expire%' OR lower(name) LIKE '%trial%' OR lower(name) LIKE '%remain%' LIMIT 50"
```

**解包后用 rg 精查（针对具体文件）**

```bash
# 签名
rg -n "getPackageInfo|GET_SIGNATURES|GET_SIGNING_CERTIFICATES|signatures" sources/

# 完整性
rg -n "MessageDigest|CRC32|classes\.dex|resources\.arsc" sources/

# 反调试
rg -n "isDebuggerConnected|waitForDebugger|TracerPid|ptrace" sources/ native/ 2>/dev/null

# 反 Frida / Xposed
rg -n "27042|frida|xposed|XposedBridge|lsposed" sources/

# root / 模拟器
rg -n "/system/bin/su|test-keys|magisk|goldfish|ranchu|isEmulator" sources/

# 时间 / 试用
rg -n "currentTimeMillis|elapsedRealtime|expire|trial|remain" sources/

# 门禁
rg -n "EULA|privacy|agreed|accepted|first_run|firstRun" sources/

# 网络判定
rg -n "isConnected|NetworkCapabilities|getActiveNetwork" sources/
```
