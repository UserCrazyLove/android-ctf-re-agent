#!/usr/bin/env bash
# 一键开案：为一个 APK 建独立工作目录
# 用法：bash new_case.sh <样本.apk> [案名] [analyze|crack]
#   analyze（默认）：逆向分析，七章 report.md
#   crack          ：CrackMe 破解，额外建 patch/ build/ test/，八章 report.md
# 例：bash ./new_case.sh ~/cases/CrackMe01.apk CrackMe01
#     bash ./new_case.sh ~/cases/CrackMe01.apk CrackMe01 crack
#
# 工作区位置：优先读环境变量 WORKSPACE，其次脚本所在目录
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${WORKSPACE:-$SCRIPT_DIR}"

APK="${1:-}"
NAME_ARG="${2:-}"
MODE="${3:-analyze}"

[ -n "$APK" ] || { echo "用法: new_case.sh <样本.apk> [案名] [analyze|crack]" >&2; exit 1; }
[ -f "$APK" ] || { echo "找不到文件: $APK" >&2; exit 1; }

case "$MODE" in
  analyze) TEMPLATE="$ROOT/_report-template.md"; EXTRA_DIRS="" ;;
  crack)   TEMPLATE="$ROOT/_crackme-template.md"; EXTRA_DIRS="patch build test" ;;
  *) echo "模式只能是 analyze 或 crack，收到: $MODE" >&2; exit 1 ;;
esac
[ -f "$TEMPLATE" ] || { echo "缺模板: $TEMPLATE" >&2; exit 1; }

base="$(basename "$APK")"
base="${base%.*}"
name="${NAME_ARG:-$base}"
# 清洗 Windows 非法字符
name="$(printf '%s' "$name" | tr ' /\\:*?"<>|' '_________')"
[ -n "$name" ] || { echo "案名为空" >&2; exit 1; }

dir="$ROOT/$name"
if [ -e "$dir" ]; then
  name="${name}_$(date +%Y%m%d_%H%M%S)"
  dir="$ROOT/$name"
fi

mkdir -p "$dir/raw" "$dir/sources" "$dir/resources" "$dir/apktool" "$dir/native" "$dir/scripts" "$dir/dump"
if [ -n "$EXTRA_DIRS" ]; then
  for d in $EXTRA_DIRS; do mkdir -p "$dir/$d"; done
fi
cp "$APK" "$dir/original.apk"

# sha256：sha256sum（Linux）或 shasum（macOS）或 certutil（Windows 兜底）
if command -v sha256sum >/dev/null 2>&1; then
  sha="$(sha256sum "$dir/original.apk" | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  sha="$(shasum -a 256 "$dir/original.apk" | cut -d' ' -f1)"
else
  sha="$(openssl dgst -sha256 "$dir/original.apk" | awk '{print $NF}')"
fi

size="$(wc -c < "$dir/original.apk" | tr -d ' ')"
now="$(date '+%Y-%m-%dT%H:%M:%S%z')"

cat > "$dir/case.json" <<JSON
{
  "case": "$name",
  "mode": "$MODE",
  "source_path": "$APK",
  "original_filename": "$(basename "$APK")",
  "sha256": "$sha",
  "size_bytes": $size,
  "created_at": "$now",
  "device": "<DEVICE>",
  "status": "opened",
  "note": ""
}
JSON

sed "s|<样本名>|$name|g" "$TEMPLATE" > "$dir/report.md"

echo "开案完成（模式: $MODE）"
echo "  目录  : $dir"
echo "  样本  : $dir/original.apk"
echo "  sha256: $sha"
echo "  大小  : $size bytes"
echo "  报告  : $dir/report.md"
if [ -n "$EXTRA_DIRS" ]; then echo "  破解目录: $EXTRA_DIRS"; fi
