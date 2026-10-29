# 示例：一条完整流程长什么样

这里不放真实样本。用虚构的 `CrackMe01.apk` 演示两种模式从开案到交付的全过程，让你知道每一步该看到什么。

---

## 场景设定

- 样本：`D:\cases\CrackMe01.apk`（虚构，一个带 VIP 功能的 App）
- 环境：Windows + git-bash
- 工作区：`D:\Android\workspace`
- 工具：`D:\Android\tools`

已在提示词里填好占位符：

```
<TOOLROOT>  = D:\Android\tools
<SDKROOT>   = D:\AndroidSDK
<WORKSPACE> = D:\Android\workspace
```

---

## 模式一：逆向分析（`bushi`）

### 第 1 步：激活

```
你：bushi D:\cases\CrackMe01.apk
```

agent 直接开跑，不反问。

### 第 2 步：开案

```bash
bash D:/Android/workspace/new_case.sh D:/cases/CrackMe01.apk CrackMe01 analyze
```

输出：

```
开案完成（模式: analyze）
  目录  : D:/Android/workspace/CrackMe01
  样本  : D:/Android/workspace/CrackMe01/original.apk
  sha256: 3f2a...
  大小  : 1843200 bytes
  报告  : D:/Android/workspace/CrackMe01/report.md
```

### 第 3 步：判壳指纹（阶段 0）

```bash
cd D:/Android/workspace/CrackMe01
apkid original.apk
aapt2 dump badging original.apk
apkInspector -apk original.apk -ll
```

结论：无壳，单 dex，arm64-v8a，入口 `com.example.crackme.MainActivity`。

### 第 4 步：定位 + 解包（阶段 1）

先用 dexsql 锁定目标（不解包，秒出）：

```bash
cd D:/Android/tools/DexSQL
dexsql.exe query --input D:/Android/workspace/CrackMe01/original.apk   --sql "SELECT class_descriptor, name FROM methods WHERE lower(name) LIKE '%license%' OR lower(name) LIKE '%vip%' LIMIT 30"
```

拿到几个可疑类，再解包精读：

```bash
cd D:/Android/workspace/CrackMe01
apktool d original.apk -o apktool
jadx -d sources --show-bad-code --no-res original.apk
```

### 第 5 步：静态定位

```bash
rg -n -i "flag|check|verify|valid|license|vip|premium" sources/
```

命中：

```
sources/com/example/crackme/LicenseManager.java:42:  public static boolean isValid(String key)
sources/com/example/crackme/PremiumActivity.java:28:  if (LicenseManager.isValid(input)) {
```

### 第 6 步：算法还原（阶段 4）

读 `LicenseManager.java`，发现：

```java
public static boolean isValid(String key) {
    if (key.length() != 16) return false;
    String hash = md5(key.substring(0, 8) + "SALT_2024");
    return hash.equals(key.substring(8));
}
```

用 Python 复现：

```python
# scripts/recover_license.py
import hashlib

def make_key(prefix8: str) -> str:
    h = hashlib.md5((prefix8 + "SALT_2024").encode()).hexdigest()
    return prefix8 + h[:8]

if __name__ == "__main__":
    print(make_key("ABCDEFGH"))
```

对拍：程序输入 `ABCDEFGH<md5前8位>` 返回 true，Python 生成的 key 也返回 true。**对拍通过。**

### 第 7 步：出报告

`report.md` 七章写满：

- 结论：flag 是 key 生成算法，示例有效 key = `ABCDEFGH<8位hash>`
- Evidence：E-001 到 E-005（文件引用 + 对拍输出）
- Findings：F-001 算法缺陷（salt 硬编码）
- Path：P-001 从入口到校验的调用链
- 复现脚本：`scripts/recover_license.py`
- Timeline
- 遗留问题：无（纯静态解决）

---

## 模式二：CrackMe 破解（`nima`）

同一个样本，换成破解模式。

### 第 1 步：激活

```
你：nima D:\cases\CrackMe01.apk
```

### 第 2 步：开案（crack 模式）

```bash
bash D:/Android/workspace/new_case.sh D:/cases/CrackMe01.apk CrackMe01-crack crack
```

这次目录里多出 `patch/`、`build/`、`test/`。

### 第 3 步：目标拆解（阶段 C0）

从 Manifest 抽自启动点：

```
Application: com.example.crackme.App
ContentProvider: （无）
入口 Activity: SplashActivity → MainActivity
```

写进 `patch/targets.md`：

| # | 目标 | 类型 | 状态 |
|---|---|---|---|
| 1 | License 校验 | 本地算法 | 待处理 |
| 2 | 签名校验 | 反篡改 | 待处理 |
| 3 | EULA 弹窗 | 门禁 | 待处理 |
| 4 | VIP 功能解锁 | 功能开关 | 待处理 |

### 第 4 步：校验点清剿（阶段 C1）

```bash
rg -n "getPackageInfo|GET_SIGNATURES|signatures" sources/
```

命中 `App.java:31`：

```java
private boolean checkSignature() {
    Signature[] sigs = getPackageManager()
        .getPackageInfo(getPackageName(), GET_SIGNATURES).signatures;
    String current = md5(sigs[0].toByteArray());
    return current.equals("a1b2c3d4...");  // 原签名 hash
}
```

### 第 5 步：Patch（阶段 C5）

**patch 1 — 签名校验短路**

`apktool/smali/com/example/crackme/App.smali`：

```smali
# 改前
.method private checkSignature()Z
    ...
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    return v0
.end method

# 改后：方法体首行直接返回 true
.method private checkSignature()Z
    const/4 v0, 0x1
    return v0
.end method
```

**patch 2 — License 校验恒真**

`LicenseManager.smali`：

```smali
.method public static isValid(Ljava/lang/String;)Z
    const/4 v0, 0x1
    return v0
.end method
```

**patch 3 — VIP 开关**

`PremiumActivity.smali` 里把 `if-eqz` 改成 `goto`。

**patch 4 — EULA 跳过**

`SplashActivity.smali` 里把 `showEulaDialog()` 的调用删掉，直接跳到 MainActivity。

每处都记进 `patch/patch-list.md`：

| # | 文件:行 | 改前 | 改后 | 目的 | 引入新检测? |
|---|---|---|---|---|---|
| 1 | App.smali:412 | `invoke equals` + `return v0` | `const/4 v0,0x1` + `return v0` | 绕过签名校验 | 否 |
| 2 | LicenseManager.smali:88 | 完整校验逻辑 | 恒返回 true | 绕过 License | 否 |
| 3 | PremiumActivity.smali:156 | `if-eqz v2, :fail` | `goto :pass` | VIP 入口直通 | 否 |
| 4 | SplashActivity.smali:74 | `invoke showEulaDialog` | （删除） | 跳过协议 | 否 |

### 第 6 步：回编签名

```bash
cd D:/Android/workspace/CrackMe01-crack
apktool b apktool -o build/unsigned.apk
zipalign -p -f 4 build/unsigned.apk build/aligned.apk
apksigner sign --ks D:/Android/tools/signer/my.jks \
  --ks-pass pass:1234567 --key-pass pass:1234567 \
  --ks-key-alias myalias --out build/CrackMe01-cracked.apk build/aligned.apk
apksigner verify --print-certs build/CrackMe01-cracked.apk
```

验证通过。

### 第 7 步：交付（停手）

agent 输出：

```
包好了：D:\Android\workspace\CrackMe01-crack\build\CrackMe01-cracked.apk
你装上试试，有问题告诉我。
```

**到此为止**。不装包、不点功能。

### 第 8 步：用户反馈

```
你：装上了，但一点 VIP 功能就闪退
```

这时才进入排查。agent 先让你导 logcat：

```bash
adb logcat -s AndroidRuntime:E > test/crash.log
```

看到 `NullPointerException` 在 `PremiumActivity.onCreate`——原来是跳过 EULA 后某个字段没初始化。

回到 `patch/targets.md` 加一行，补上初始化，重新回编签名，再次交付路径。

### 第 9 步：报告

`report.md` 八章，第 1 章结论写清：

- 可安装：是
- 可运行：是（冷启动直达主界面）
- 已解锁功能：VIP 导出、高级设置
- 已拆除门禁：EULA
- 已绕过自检：签名校验
- 本地化程度：完全离线
- 残留限制：无

第 7 章回归矩阵的「实际」列，填的是用户反馈的结果，不是 agent 自己测的。

---

## 两种模式的关键差异

| | `bushi`（分析） | `nima`（破解） |
|---|---|---|
| 交付物 | report.md | 破解包 + 报告 |
| 结束标志 | 七章写完 | apk 路径交给用户 |
| 验证 | Python 对拍 | 用户装机测试 |
| 目录 | 无 patch/build/test | 有 patch/build/test |
| 报告章数 | 七章 | 八章 |

---

## 常见节奏

一次完整破解通常是这样：

1. 开案 + 判壳（5 分钟）
2. 解包 + 定位校验点（20–60 分钟，看混淆程度）
3. 列 targets.md（10 分钟）
4. 逐个 patch（30–90 分钟）
5. 回编签名（5 分钟）
6. 交付 → 等用户反馈
7. 按反馈迭代（可能 2–3 轮）

**加壳样本**会显著拉长时间，因为要先把真实 dex 拿出来。

**有反调试/反 Frida 的样本**，如果是静态定位，时间长；如果非要动态，得走真机流程。
