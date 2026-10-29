# CrackMe 破解方法论

四条需求，四种打法。这份文档是对提示词「执行流程 B」的展开，讲清每一步**为什么**这么做、卡住时往哪想。

---

## 总览

| 需求 | 术语 | 本质 | 主要战场 |
|---|---|---|---|
| 判断并去除验证、解锁全部功能 | License check bypass + Feature unlock | 找到"决定功能开关的那个布尔值/判断"，让它永远为真 | smali / Java 层 |
| 去除各种自检 | Anti-tamper bypass | 找到"发现你改了包就罢工"的检测点，短路掉 | smali + so |
| 彻底功能本地化 | Server-side emulation / Offline crack | 把"必须联网才给的功能"变成本地可判定 | 客户端判定 + mock |
| 去除使用协议 | EULA / First-run gate bypass | 跳过启动门禁 | Activity / Dialog |

**核心心法**：CrackMe 不是"把代码改坏"，是"让程序相信它该给的东西已经给了"。每一次 patch 都是在回答一个具体问题：**哪一行代码决定了这个行为？**

---

## 一、验证去除与功能解锁

### 1.1 先找"功能开关"在哪

不要一上来就搜 `isVip`。按这个顺序：

1. **dexsql 捞出所有疑似开关**（一条 SQL 秒出）：

```bash
cd <TOOLROOT>/DexSQL
# 疑似校验方法
dexsql.exe query --input app.apk --sql "SELECT class_descriptor, name, descriptor FROM methods WHERE lower(name) LIKE '%vip%' OR lower(name) LIKE '%premium%' OR lower(name) LIKE '%check%' OR lower(name) LIKE '%valid%' LIMIT 80"
# 疑似开关字段
dexsql.exe query --input app.apk --sql "SELECT class_descriptor, name, descriptor FROM fields WHERE lower(name) LIKE '%vip%' OR lower(name) LIKE '%premium%' OR lower(name) LIKE '%pro%' OR lower(name) LIKE '%paid%' LIMIT 80"
# 字符串池里的会员文案
dexsql.exe query --input app.apk --sql "SELECT value FROM strings WHERE value LIKE '%VIP%' OR value LIKE '%会员%' OR value LIKE '%开通%' LIMIT 50"
```

2. **追调用链**（dexsql 的 `method_calls` 表）：

```bash
# 谁调用了某个开关方法
dexsql.exe query --input app.apk --sql "SELECT method_class, method_name FROM method_calls WHERE callee_name = 'isVip'"
# 某个方法调了谁（往下追到实际执行）
dexsql.exe query --input app.apk --sql "SELECT callee_class, callee_name FROM method_calls WHERE method_name = 'onVipClick' LIMIT 30"
```

3. **UI 层确认入口**：jadx 打开那个 Activity，看 `android:onClick` 或 `setOnClickListener` 绑到哪个方法
4. **找那个决定分支的变量**：通常是 `boolean`、`int` 等级、`String` 会员类型

```java
// 典型形态
if (UserManager.getInstance().isVip()) {
    doPremiumThing();
} else {
    showPayDialog();
}
```

这里要改的**不是** `isVip()`，而是**让判断恒真**，或者让 `doPremiumThing()` 无条件执行。两种改法各有适用场景：

| 改法 | 优点 | 缺点 |
|---|---|---|
| 让 `isVip()` 恒返回 true | 一处改完全局生效 | 如果有二次校验会露馅 |
| 改调用点的分支 | 精准，不动全局状态 | 每个调用点都要改 |

**经验**：功能多、调用点分散时改 `isVip()`；只有一两个入口时改调用点。

### 1.2 常见验证形态对照

| 形态 | 特征 | 改法 |
|---|---|---|
| 布尔方法 | `private boolean checkXxx()` | 方法体首行 `const/4 v0, 0x1` + `return v0` |
| 等级判定 | `if (level >= 2)` | 改常量，或把 `if-lt` 反转 |
| 到期时间 | `System.currentTimeMillis() < expireTime` | 把 `expireTime` 改成极大值 |
| 剩余次数 | `remain > 0` | 改成 `remain = 999` 或分支恒真 |
| 服务端字段 | `resp.isVip` | 解析后直接赋值 true |
| 加密令牌 | 校验签名/解密的 token | 还原算法后本地生成/直接跳过比较 |
| 数据库/SP 标志 | `getInt("vip", 0)` | 改成默认值 1，或改读取后的判断 |

### 1.3 解锁后必须验证"真的能用"

这是最容易翻车的一步。程序显示"已解锁"不等于功能可用：

- 有的 App 只是把锁图标换掉了，实际功能调用另一个方法又检查一次
- 有的 App 在下载/导出时才校验，前面都能进
- 有的 App 会异步请求服务端确认，本地改的只是 UI

**验证方法**：每个解锁的功能都走完整流程，直到产出结果（导出文件、下载内容、生成内容），不能停在"界面打开了"。

---

## 二、反篡改与反分析对抗

### 2.1 为什么必须先处理这类检测

你改完 smali、重签名、装上——闪退。九成不是业务代码改错了，是**检测发现你动了包**。

所以顺序很重要：**先摸清有哪些检测点，再动手改业务逻辑**。否则改一处触发一处，来回折腾。

### 2.2 检测点全表

见 [`anti-tamper-checklist.md`](anti-tamper-checklist.md)。这里只讲打法。

### 2.3 三类打法

| 打法 | 适用 | 操作 |
|---|---|---|
| **短路** | 检测函数返回 boolean | 让函数恒返回"通过"的值 |
| **移除** | 检测只是一段调用 | 注释掉 `invoke-*`，注意寄存器后续依赖 |
| **改数据源** | 检测读取某个值再比对 | 让读到的值等于期望值（如签名摘要） |

**优先短路**，因为最不容易破坏后续逻辑。

### 2.4 签名校验的具体处理

```smali
# 原始
invoke-virtual {p0}, Landroid/content/pm/PackageManager;->getPackageInfo(...)
# 拿到 signatures 后与内置 hash 比对
```

改法三选一：

1. 让比对函数恒返回 true
2. 让 `signatures` 的读取返回内置的正确值（伪造）
3. 删掉整个校验调用

**第 2 种最隐蔽**，因为后续其他地方如果也用这个值，不会出错。

### 2.5 加载失败回查顺序（重要）

改完装不上/闪退/白屏，按这个顺序查，**不要盲改**：

1. `adb logcat -s AndroidRuntime:E` 看崩溃栈，确认异常类型
2. 签名相关 → 搜 `GET_SIGNATURES`、`signatures`、`getPackageInfo`
3. 完整性相关 → 搜 `MessageDigest`、`CRC32`、`classes.dex`
4. so 加载失败 → `unzip -l` 看 `lib/` 是否还在
5. 启动即退出 → 查 `attachBaseContext` / `ContentProvider.onCreate` 里的 `System.exit`
6. native crash → `/data/tombstones/` 看 so 偏移
7. 白屏无崩溃 → 查主题、跳转条件、启动页门禁
8. 都排除后才回头查业务 patch

**为什么不先查业务代码**：业务改错通常表现为"功能不对"，不是"根本起不来"。起不来基本是检测。

---

## 三、功能本地化

### 3.1 判断依赖类型

先搞清楚这个功能依赖什么：

| 依赖 | 特征 | 处理难度 |
|---|---|---|
| 本地常量 | 代码里写死的开关/日期 | 最简单，直接改 |
| 本地文件 | 读 `.lic`、`.dat`、SP | 简单，伪造或改解析 |
| 服务端回包 | 请求后按字段判定 | 中等，改客户端判定 |
| 服务端下发内容 | 功能数据本身在服务端 | 最难，需要 mock |

**处理顺序**：从简单到难，能停在客户端就不碰服务端。

### 3.2 客户端判定的改法

服务端回包后，客户端一定会有一处 `if`：

```java
JSONObject resp = ...;
if (resp.optInt("code") == 0 && resp.optInt("vip") == 1) {
    unlock();
}
```

改法：把整个 `if` 短路成恒真，或把 `resp` 解析后的值强制赋值。

**关键**：不要改服务端（也不该改），只改客户端对回包的解读。

### 3.3 License / 激活码

三种情况：

1. **纯本地算法**：输入 → 变换 → 与常量比。还原算法，写 keygen 生成有效码。
2. **本地算法 + 服务端确认**：先本地算，再发服务端确认。改成本地算完就通过。
3. **纯服务端验证**：本地只发请求。改客户端判定，或 mock 响应。

keygen 写好后放 `scripts/keygen.py`，要能批量生成并自动验证。

### 3.4 离线化

最彻底的做法是让"必须联网"的判定失效：

```java
if (!NetworkUtils.isConnected()) {
    showNoNetwork();
    return;
}
```

改成不检查，或让 `isConnected()` 恒返回 true。

但要注意：**有些功能真的需要服务端数据**（比如在线内容、云端配置）。这种情况下：

- 要么本地 mock 一个固定返回
- 要么把数据缓存下来内置进 assets
- 要么承认做不到完整离线，在报告里如实写

**不要假装离线可用**。断网测试跑不通就是跑不通，写进「残留问题」。

---

## 四、门禁拆除

### 4.1 EULA / 隐私协议

定位：

- 搜 `Dialog`、`AlertDialog`、`BottomSheet` 相关
- 搜"同意""隐私""协议""条款"的字符串资源 ID
- 找 `SharedPreferences` 里的 `agreed` / `accepted` / `first_run` 键

改法：

1. 让"是否已同意"的判断恒真
2. 把对应的 SP 键默认值改成已同意
3. 直接跳过那个 Activity（改 Manifest 入口或跳转逻辑）

**第 2 种最稳**，因为不影响 UI 流程。

### 4.2 强制更新

定位：版本比较逻辑，通常是 `versionCode` 或 `versionName` 比较。

改法：

- 把"需要更新"的判断恒假
- 或把当前版本号改大（改 `AndroidManifest` 的 `versionCode`，但这会影响安装）
- 或直接跳过更新对话框

**注意**：有些 App 更新弹窗是"不可取消"的，要同时处理 `setCancelable` 和返回键。

### 4.3 首启引导

`first_run` 标志，通常在 SP 或数据库里。改默认值为"已引导"。

### 4.4 登录墙

- 能跳过的：直接跳过
- 必须登录的：本地伪造登录态（token、uid、会员字段）
- 有服务端校验的：改判定，不要真的去登录

---

## 五、Patch 与回编

### 5.1 smali 改法速查

| 目的 | smali 写法 |
|---|---|
| 返回 true | `const/4 v0, 0x1` + `return v0` |
| 返回 false | `const/4 v0, 0x0` + `return v0` |
| 返回 0 | `const/4 v0, 0x0` + `return v0` |
| 返回大数 | `const v0, 0x7fffffff` + `return v0` |
| void 直接返回 | `return-void` |
| 跳过分支 | `if-eqz v0, :cond_x` → `goto :cond_x` |
| 无条件执行 | 删掉判断行，保留目标代码 |

### 5.2 寄存器注意事项

改 `const/4` 时要注意返回值类型：

- 返回 `boolean` / `int` → `const/4 v0, 0x1`
- 返回 `long` → `const-wide v0, 0x1L`
- 返回对象 → 不能简单 const，要 `new-instance` 或返回已有实例

**改错类型会 `VerifyError`**，装上去直接闪退。

### 5.3 回编签名流程

```bash
apktool b apktool -o build/unsigned.apk
zipalign -p -f 4 build/unsigned.apk build/aligned.apk
apksigner sign --ks <KEYSTORE> ... --out build/<案名>-cracked.apk build/aligned.apk
apksigner verify --print-certs build/<案名>-cracked.apk
```

**顺序绝对不能反**：先 sign 后 align 会破坏签名。

### 5.4 交付就停手

签名验证通过后，把路径给用户，**不要自己 `adb install`**。

用户装上后反馈问题，才进入排查。

---

## 六、常见失败模式

| 现象 | 最可能原因 | 第一步 |
|---|---|---|
| 装完闪退 | 签名/完整性检测 | logcat 看栈 |
| 白屏 | 启动页被门禁拦截 | 查 Splash 的跳转条件 |
| 卡在启动画面 | 反调试死等 | 查 `waitForDebugger` |
| 功能显示已解锁但用不了 | 二次校验 | 追功能实际调用的方法 |
| 改完没变化 | 改错了 smali 目录 | 核对 `apktool.yml` dex 数量 |
| `VerifyError` | 寄存器类型不对 | 检查 const 指令与返回类型 |
| `UnsatisfiedLinkError` | so 丢了或被压缩 | `unzip -l` 检查 |
| 断网就废 | 本地化没做透 | 找 `isConnected` 类判断 |

---

## 七、定位工具的选择

| 目的 | 工具 | 原因 |
|---|---|---|
| 找「哪个类里有 checkVip」 | `dexsql query` | 毫秒级，不用解包 |
| 追「谁调用了 isVip」 | `dexsql` 的 `method_calls` 表 | 直接出调用图，比 rg 准 |
| 看「某个方法完整逻辑」 | `jadx` | 出可读 Java |
| 看「某个方法原始指令」 | `dexsql decode` 或 apktool | 出 smali |
| 改「smali 后回编」 | apktool | 唯一能回编的 |

**dexsql 不做 Java 反编译**，它出 SQL 结果和 smali。别指望它替代 jadx。

---

## 八、一条原则

**最小改动**。

- 能改一个跳转，就不重写整个方法
- 能停在 Java 层，就不下沉到 so
- 能短路一个判断，就不重构整段逻辑

改得越少，引入新问题的概率越低，报告也越好写。
