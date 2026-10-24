# 跨案公用脚本

放这里的是可以在多个案子里复用的脚本，不要在每个案子的 `scripts/` 下复制 N 份。

## 约定

- 案子专属的脚本 → `<WORKSPACE>/<案名>/scripts/`
- 跨案通用的脚本 → 本目录
- 每个脚本顶部写清用途、用法、依赖

## 建议放这里的脚本

| 脚本 | 用途 |
|---|---|
| `batch_apkid.sh` | 批量判壳，扫一个目录下所有 apk |
| `batch_unpack.sh` | 批量 apktool + jadx 解包 |
| `sign_apk.sh` | 统一的回编 + 对齐 + 签名流程 |
| `hash_files.py` | 算目录下所有文件的 sha256，便于做完整性对比 |
| `smali_diff.py` | 对比原 smali 与改后 smali，生成 patch 清单 |
| `dump_strings.sh` | 批量提字符串（rabin2 + rg） |

## 自己的脚本

按需添加。加之前先确认：这东西是不是只有一个案子会用？是的话放案子目录里就行。

---

## 一个可直接用的例子：批量签名

```bash
#!/usr/bin/env bash
# sign_apk.sh — 回编 + 对齐 + 签名一条龙
# 用法：sign_apk.sh <apktool目录> <输出apk路径>
set -euo pipefail

KEYSTORE="${KEYSTORE:?请先设 KEYSTORE 环境变量}"
KEYSTORE_PASS="${KEYSTORE_PASS:?请先设 KEYSTORE_PASS}"
KEY_ALIAS="${KEY_ALIAS:?请先设 KEY_ALIAS}"

SRC="${1:?用法: sign_apk.sh <apktool目录> <输出apk>}"
OUT="${2:?用法: sign_apk.sh <apktool目录> <输出apk>}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

apktool b "$SRC" -o "$TMP/unsigned.apk"
zipalign -p -f 4 "$TMP/unsigned.apk" "$TMP/aligned.apk"
apksigner sign --ks "$KEYSTORE" \
  --ks-pass "pass:$KEYSTORE_PASS" --key-pass "pass:$KEYSTORE_PASS" \
  --ks-key-alias "$KEY_ALIAS" --out "$OUT" "$TMP/aligned.apk"
apksigner verify --print-certs "$OUT"

echo "签名完成: $OUT"
sha256sum "$OUT"
```

用：

```bash
export KEYSTORE=~/android-re/tools/signer/my.jks
export KEYSTORE_PASS=你的密码
export KEY_ALIAS=你的别名
bash sign_apk.sh work/CrackMe01/apktool work/CrackMe01/build/cracked.apk
```
