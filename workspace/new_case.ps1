# 一键开案：为一个 APK 建独立工作目录（PowerShell 版）
# 用法：
#   .\new_case.ps1 -Apk .\CrackMe01.apk
#   .\new_case.ps1 -Apk .\CrackMe01.apk -Name CrackMe01 -Mode crack
#
# 工作区位置：优先读环境变量 WORKSPACE，其次脚本所在目录

param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Name = "",
    [ValidateSet("analyze", "crack")][string]$Mode = "analyze"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = if ($env:WORKSPACE) { $env:WORKSPACE } else { $ScriptDir }

if (-not (Test-Path $Apk)) { throw "找不到文件: $Apk" }

$Template = if ($Mode -eq "crack") { Join-Path $Root "_crackme-template.md" } else { Join-Path $Root "_report-template.md" }
$ExtraDirs = if ($Mode -eq "crack") { @("patch", "build", "test") } else { @() }

if (-not (Test-Path $Template)) { throw "缺模板: $Template" }

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($Apk)
$CaseName = if ($Name) { $Name } else { $BaseName }
$Invalid = [System.IO.Path]::GetInvalidFileNameChars() + [char[]]' /'
foreach ($ch in $Invalid) { $CaseName = $CaseName.Replace($ch, '_') }
if (-not $CaseName) { throw "案名为空" }

$CaseDir = Join-Path $Root $CaseName
if (Test-Path $CaseDir) {
    $CaseName = "${CaseName}_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $CaseDir = Join-Path $Root $CaseName
}

$BaseDirs = @("raw", "sources", "resources", "apktool", "native", "scripts", "dump") + $ExtraDirs
foreach ($d in $BaseDirs) { New-Item -ItemType Directory -Force -Path (Join-Path $CaseDir $d) | Out-Null }

$Original = Join-Path $CaseDir "original.apk"
Copy-Item $Apk $Original

$Sha = (Get-FileHash -Algorithm SHA256 $Original).Hash.ToLower()
$Size = (Get-Item $Original).Length
$Now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

$CaseJson = [ordered]@{
    case              = $CaseName
    mode              = $Mode
    source_path       = (Resolve-Path $Apk).Path
    original_filename = (Split-Path $Apk -Leaf)
    sha256            = $Sha
    size_bytes        = $Size
    created_at        = $Now
    device            = "<DEVICE>"
    status            = "opened"
    note              = ""
} | ConvertTo-Json

$CaseJson | Set-Content -Path (Join-Path $CaseDir "case.json") -Encoding UTF8

# 生成报告骨架，替换 <样本名>
$TemplateText = Get-Content $Template -Raw -Encoding UTF8
$TemplateText = $TemplateText -replace '<样本名>', $CaseName
$TemplateText | Set-Content -Path (Join-Path $CaseDir "report.md") -Encoding UTF8

Write-Host "开案完成（模式: $Mode）"
Write-Host "  目录  : $CaseDir"
Write-Host "  样本  : $Original"
Write-Host "  sha256: $Sha"
Write-Host "  大小  : $Size bytes"
Write-Host "  报告  : $(Join-Path $CaseDir 'report.md')"
if ($ExtraDirs.Count -gt 0) { Write-Host "  破解目录: $($ExtraDirs -join ', ')" }
