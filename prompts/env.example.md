# 环境占位符配置

主提示词 `ctf-reverse-system.md` 里所有路径都用尖括号占位符。这份文件说明每个占位符怎么填，并给三套典型配置。

---

## 占位符总表

| 占位符 | 含义 | 常见取值 |
|---|---|---|
| `<TOOLROOT>` | 逆向工具根目录 | `D:\Android\tools`、`~/android-re/tools`、`/opt/re/tools` |
| `<SDKROOT>` | Android SDK 根目录 | `D:\AndroidSDK`、`~/android-re/sdk` |
| `<WORKSPACE>` | 一案一目录的工作区根 | `D:\Android\workspace`、`~/android-re/workspace` |
| `<PYTHON>` | 装了逆向依赖的解释器 | `<TOOLROOT>\venv\Scripts\python.exe`、`<TOOLROOT>/venv/bin/python` |
| `<JAVA_HOME>` | JDK 21 | `<TOOLROOT>\jdk21\jdk-21.0.12.1+1` |
| `<JDK8>` | JDK 8（老工具用） | `<TOOLROOT>\jdk8` |
| `<KEYSTORE>` | 重签名证书 | `<TOOLROOT>\signer\my-release.jks` |
| `<KEYSTORE_PASS>` | 证书密码（store / key 同值） | 你自己设的 |
| `<KEY_ALIAS>` | 证书别名 | 你自己设的 |
| `<DEVICE>` | 测试真机（只做静态可留空） | 例：Pixel 7 / Android 14 / Magisk root |

---

## 三套典型配置

### 配置 A：Windows + git-bash（最常见）

```markdown
| 占位符 | 值 |
|---|---|
| `<TOOLROOT>` | `D:\Android\tools` |
| `<SDKROOT>` | `D:\AndroidSDK` |
| `<WORKSPACE>` | `D:\Android\workspace` |
| `<PYTHON>` | `D:\Android\tools\venv\Scripts\python.exe` |
| `<JAVA_HOME>` | `D:\Android\tools\jdk21\jdk-21.0.12.1+1` |
| `<JDK8>` | `D:\Android\tools\jdk8` |
| `<KEYSTORE>` | `D:\Android\tools\signer\my-release.jks` |
| `<KEYSTORE_PASS>` | `你的密码` |
| `<KEY_ALIAS>` | `你的别名` |
| `<DEVICE>` | `Pixel 7 / Android 14 / Magisk` |
```

**注意**：git-bash 里给原生 exe 传路径写 `D:/Android/...`（正斜杠），不要写 `/d/Android/...`。

### 配置 B：Linux

```markdown
| 占位符 | 值 |
|---|---|
| `<TOOLROOT>` | `/home/you/android-re/tools` |
| `<SDKROOT>` | `/home/you/android-re/sdk` |
| `<WORKSPACE>` | `/home/you/android-re/workspace` |
| `<PYTHON>` | `/home/you/android-re/tools/venv/bin/python` |
| `<JAVA_HOME>` | `/home/you/android-re/tools/jdk21/jdk-21.0.12.1+1` |
| `<JDK8>` | `/home/you/android-re/tools/jdk8` |
| `<KEYSTORE>` | `/home/you/android-re/tools/signer/my-release.jks` |
| `<KEYSTORE_PASS>` | `你的密码` |
| `<KEY_ALIAS>` | `你的别名` |
| `<DEVICE>` | `Pixel 7 / Android 14 / Magisk` |
```

### 配置 C：macOS（Apple Silicon）

```markdown
| 占位符 | 值 |
|---|---|
| `<TOOLROOT>` | `/Users/you/android-re/tools` |
| `<SDKROOT>` | `/Users/you/android-re/sdk` |
| `<WORKSPACE>` | `/Users/you/android-re/workspace` |
| `<PYTHON>` | `/Users/you/android-re/tools/venv/bin/python` |
| `<JAVA_HOME>` | `/Users/you/android-re/tools/jdk21/Contents/Home` |
| `<JDK8>` | `/Users/you/android-re/tools/jdk8/Contents/Home` |
| `<KEYSTORE>` | `/Users/you/android-re/tools/signer/my-release.jks` |
| `<KEYSTORE_PASS>` | `你的密码` |
| `<KEY_ALIAS>` | `你的别名` |
| `<DEVICE>` | `Pixel 7 / Android 14 / Magisk` |
```

**注意**：Ghidra 和 frida-server 在 Apple Silicon 上要挑对应架构的包。

---

## 替换方法

### 方法一：手动改

打开 `prompts/ctf-reverse-system.md`，找到「环境事实」那一节，把表格里「本机示例」那一列换掉。

### 方法二：脚本替换

```bash
# Linux / macOS / git-bash
TOOLROOT="/home/you/android-re/tools"
SDKROOT="/home/you/android-re/sdk"
WORKSPACE="/home/you/android-re/workspace"
PYTHON="$TOOLROOT/venv/bin/python"
JAVA_HOME_V="$TOOLROOT/jdk21/jdk-21.0.12.1+1"
JDK8_V="$TOOLROOT/jdk8"

sed -i.bak \
  -e 's|<TOOLROOT>|'"$TOOLROOT"'|g' \
  -e 's|<SDKROOT>|'"$SDKROOT"'|g' \
  -e 's|<WORKSPACE>|'"$WORKSPACE"'|g' \
  -e 's|<PYTHON>|'"$PYTHON"'|g' \
  -e 's|<JAVA_HOME>|'"$JAVA_HOME_V"'|g' \
  -e 's|<JDK8>|'"$JDK8_V"'|g' \
  prompts/ctf-reverse-system.md
```

### 方法三：让 agent 自己问

不改提示词也行。在会话开头补一句：

```
环境变量：TOOLROOT=D:\Android\tools，SDKROOT=D:\AndroidSDK，
WORKSPACE=D:\Android\workspace，其余按 <TOOLROOT> 推导。
下文所有 <TOOLROOT> 等占位符按此展开。
```

agent 会自己展开。

---

## 常见问题

**Q：能不能全部用相对路径？**
不建议。工作区在 `<WORKSPACE>`，工具在 `<TOOLROOT>`，两者不在同一个父目录时相对路径会乱。写绝对路径最稳。

**Q：`<DEVICE>` 不填行不行？**
行。只做静态分析时用不到；真机档触发时 agent 会先问你，那时再补。

**Q：密码写进提示词里安全吗？**
只是本地靶场自签证书，风险低。介意的话把 `<KEYSTORE_PASS>` 留空，让 agent 每次问你。

**Q：换机器怎么办？**
只改这张表，正文一个字不用动。这也是当初把路径抽出来的原因。
