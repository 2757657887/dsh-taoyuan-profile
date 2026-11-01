#requires -version 5.1
<#
  核对某个 DSH profile 是否与本仓库清单一致（只读，不改任何东西）。

  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
    .\verify.ps1 -ProfileName desktop
#>
[CmdletBinding()]
param([string]$ProfileName = 'desktop')

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$manifest = Get-Content (Join-Path $repo 'plugins.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$profileDir = Join-Path $env:USERPROFILE ".dsh\profiles\$ProfileName"
if (-not (Test-Path $profileDir)) { throw "profile 不存在：$profileDir" }

$pkgPath = Join-Path $profileDir 'package.json'
$pkg = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nm = Join-Path $profileDir 'node_modules'

function Get-InstalledVersion([string]$name) {
  $p = Join-Path $nm "$name\package.json"
  if (-not (Test-Path $p)) { return $null }
  try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch { return '?' }
}

Write-Host "`nprofile: $profileDir" -ForegroundColor Cyan
Write-Host ('{0,-40} {1,-58} {2,-12} {3}' -f 'plugin', 'manifest', 'installed', 'check')
Write-Host ('-' * 120)

$problems = @()
foreach ($plugin in $manifest.plugins) {
  $spec = $plugin.spec
  $expected = if ($plugin.kind -eq 'npm') { $spec.Substring($spec.LastIndexOf('@') + 1) } else { $null }
  $installed = Get-InstalledVersion $plugin.name

  $mark = 'ok'
  if (-not $installed) {
    $mark = 'MISSING'
    $problems += "$($plugin.name): 未安装"
  } elseif ($plugin.kind -eq 'npm' -and $installed -ne $expected) {
    $mark = 'DIFF'
    $problems += "$($plugin.name): 清单 $expected，实际 $installed"
  }

  $color = switch ($mark) { 'ok' { 'Gray' } 'MISSING' { 'Red' } default { 'Yellow' } }
  Write-Host ('{0,-40} {1,-58} {2,-12} {3}' -f $plugin.name, $spec, $installed, $mark) -ForegroundColor $color
}

$bundles = @($pkg.dsh.profile.bundles)
$missing = @($manifest.bundles | Where-Object { $bundles -notcontains $_ })
$extra = @($bundles | Where-Object { $manifest.bundles -notcontains $_ })

Write-Host "`nbundles: 清单 $($manifest.bundles.Count) / 实际 $($bundles.Count)" -ForegroundColor Cyan
if ($missing.Count) { Write-Host "  清单有、实际缺：$($missing -join ', ')" -ForegroundColor Yellow }
if ($extra.Count) { Write-Host "  实际有、清单无（内置或额外插件）：$($extra -join ', ')" -ForegroundColor DarkGray }

$patchPath = Join-Path $profileDir 'cordis.patch.yml'
$patchOk = Test-Path $patchPath
Write-Host "`ncordis.patch.yml: $(if ($patchOk) { '存在' } else { '缺失' })" -ForegroundColor $(if ($patchOk) { 'Gray' } else { 'Red' })

$expectedPatch = Join-Path $repo 'profile\cordis.patch.yml'
if ($patchOk -and (Test-Path $expectedPatch)) {
  $same = (Get-FileHash $patchPath).Hash -eq (Get-FileHash $expectedPatch).Hash
  Write-Host "  与仓库版本: $(if ($same) { '一致' } else { '不同（可能被本机改过）' })" -ForegroundColor $(if ($same) { 'Gray' } else { 'Yellow' })
}

if ($problems.Count) {
  Write-Host "`n不一致 $($problems.Count) 项：" -ForegroundColor Yellow
  $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
  exit 1
}
Write-Host "`n插件与清单一致。" -ForegroundColor Green
