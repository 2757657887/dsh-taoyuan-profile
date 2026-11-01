#requires -version 5.1
<#
  在目标机器上还原 DSH profile：写入配置补丁 + 按清单安装插件。

  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
    .\install.ps1 -ProfileName desktop -DryRun

  说明：
    - 只改 <用户目录>\.dsh\profiles\<profile>\ 这一层，不碰 DSH 应用本体。
    - 会在覆盖前备份已有的 cordis.patch.yml。
    - 不包含任何密钥：模型凭据与环境变量需要你自己准备（见 README）。
#>
[CmdletBinding()]
param(
  [string]$ProfileName = 'desktop',
  [switch]$SkipPatch,
  [switch]$DryRun
)

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$manifestPath = Join-Path $repo 'plugins.json'
$patchSource = Join-Path $repo 'profile\cordis.patch.yml'

function Write-Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Write-Ok($text) { Write-Host "   ok  $text" -ForegroundColor Green }
function Write-Warn2($text) { Write-Host "   !   $text" -ForegroundColor Yellow }

Write-Step '检查环境'

$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if (-not $dsh) {
  throw "找不到 dsh 命令。先安装 DeepSeek Harness 桌面端，并把 <安装目录>\resources\runtime\cli\bin 加进 PATH。"
}
Write-Ok "dsh -> $($dsh.Source)"

if (-not (Test-Path $manifestPath)) { throw "缺少 plugins.json：$manifestPath" }
if (-not (Test-Path $patchSource)) { throw "缺少 profile\cordis.patch.yml：$patchSource" }

$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

$dshHome = Join-Path $env:USERPROFILE '.dsh'
$profileDir = Join-Path $dshHome "profiles\$ProfileName"
if (-not (Test-Path $profileDir)) {
  throw "profile '$ProfileName' 不存在：$profileDir`n先启动一次 DSH，让它初始化 profile（安装插件时 profile 必须已存在）。"
}
Write-Ok "profile -> $profileDir"
Write-Host "   要求 DSH $($manifest.dsh.minVersion)+ ；实测 $($manifest.dsh.testedWith)"

if ($DryRun) { Write-Warn2 'DryRun：只打印命令，不落盘' }

Write-Step '写入配置补丁'

$patchTarget = Join-Path $profileDir 'cordis.patch.yml'
if ($SkipPatch) {
  Write-Warn2 '按参数跳过 cordis.patch.yml'
} elseif ($DryRun) {
  Write-Host "   cp $patchSource -> $patchTarget"
} else {
  if (Test-Path $patchTarget) {
    $backup = "$patchTarget.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $patchTarget $backup -Force
    Write-Ok "已备份原补丁 -> $backup"
  }
  Copy-Item $patchSource $patchTarget -Force
  Write-Ok '已写入 cordis.patch.yml'
}

Write-Step "安装插件（$($manifest.plugins.Count) 个）"

$failed = @()
$index = 0
foreach ($plugin in $manifest.plugins) {
  $index++
  if ($DryRun) {
    Write-Host "   dsh plugin --profile $ProfileName add `"$($plugin.spec)`"   # [${index}] $($plugin.name)"
    continue
  }
  Write-Host "   [${index}/$($manifest.plugins.Count)] $($plugin.name)" -ForegroundColor DarkGray
  & dsh plugin --profile $ProfileName add "$($plugin.spec)" 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
  if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "$($plugin.name) 安装失败（exit $LASTEXITCODE）"
    $failed += $plugin.name
  } else {
    Write-Ok $plugin.name
  }
}

Write-Step '结果'

if ($failed.Count -gt 0) {
  Write-Warn2 '以下插件安装失败，可重跑本脚本或单独重试：'
  $failed | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
} else {
  Write-Ok '插件安装步骤完成'
}

$profilePkgPath = Join-Path $profileDir 'package.json'
if ((Test-Path $profilePkgPath) -and -not $DryRun) {
  $pkg = Get-Content $profilePkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $installed = @($pkg.dsh.profile.bundles)
  $missingBundles = @($manifest.bundles | Where-Object { $installed -notcontains $_ })
  if ($missingBundles.Count -gt 0) {
    Write-Warn2 '以下 bundle 不在 dsh.profile.bundles 中（应用内置的实验特性或未装插件，需要时在设置里开启）：'
    $missingBundles | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
  }
}

Write-Step '下一步'
Write-Host @'
   1. 完全退出并重启 DSH。
   2. 检查右侧栏、设置页、插件列表是否符合预期。
   3. 重新登录：凭据不在本仓库内（.credentials.yaml 是本地密钥库）。
   4. 默认模型是 opencode-go / deepseek-v4.1-flash，需要环境变量 OPENCODE_GO_API_KEY。
   5. 自定义 agent 预设（.agent-presets）不在本仓库内，需要时自行复制。
'@ -ForegroundColor Gray
