<#
  Codex 通道切换器（Windows 版）
  ------------------------------------------------------------------
  作用：在 %USERPROFILE%\.codex\config.toml 里一键切换
        「DeepSeek 通道」和「GPT（ChatGPT 登录）通道」。

  与 macOS 版的对应关系：
    ~/.codex/切到DeepSeek.command      -> 切到DeepSeek.bat
    ~/.codex/切到GPT.command           -> 切到GPT.bat
    ~/.codex/models.json               -> %USERPROFILE%\.codex\models.json
    [model_providers.deepseek] 段      -> 由本脚本一次性写入

  参数：
    -Mode install     一次性安装（写 provider 段 / models.json / 桌面图标，然后切到 DeepSeek）
    -Mode deepseek    切到 DeepSeek 通道
    -Mode gpt         切到 GPT 通道（保留 DeepSeek 的 provider 配置，只是不启用）
    -Mode toggle      自动判断当前通道并切到另一边
    -Mode status      只查看当前通道，不改任何文件
    -Mode restore     把 config.toml 恢复成最近一次备份
    -Mode uninstall   停用 DeepSeek 通道并删除桌面图标
    -Mode selftest    逻辑自检（用样例文本跑一遍，不动你的配置）
    -CodexHome <路径> 指定 .codex 目录（默认 %USERPROFILE%\.codex）
    -NoPause          结束时不等待回车
#>
[CmdletBinding()]
param(
    [ValidateSet('install', 'deepseek', 'gpt', 'toggle', 'status', 'restore', 'uninstall', 'selftest')]
    [string]$Mode = 'install',
    [string]$CodexHome = '',
    [switch]$NoPause
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ------------------------------------------------------------------ 常量

$DsModel = 'deepseek-flash'
$DsProviderName = 'deepseek'
$DsBaseUrl = 'https://api.deepseek.com/'
$DsWireApi = 'responses'

$ReProviderHead = '^\[\s*model_providers\.deepseek\s*\]\s*$'
$ReAnyTableHead = '^\s*\['
$ReModelAny = '^\s*#?\s*model\s*='
$ReProviderAny = '^\s*#?\s*model_provider\s*='
$ReCatalogAny = '^\s*#?\s*model_catalog_json\s*='
$ReModelActiveValue = '^\s*model\s*=\s*"([^"]*)"\s*$'
$ReModelCommentedValue = '^\s*#\s*model\s*=\s*"([^"]*)"'
$ReModelDsActive = '^\s*model\s*=\s*"deepseek-flash"\s*$'
$ReProviderDsActive = '^\s*model_provider\s*=\s*"deepseek"\s*$'
$ReCatalogActive = '^\s*model_catalog_json\s*='
$ReLineBreak = "\r\n|\n"

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

$OnWindows = ([System.Environment]::OSVersion.Platform -eq 'Win32NT')

# ------------------------------------------------------------------ 基础工具

function Resolve-CodexRoot {
    if ($CodexHome -ne '') { return $CodexHome }
    $envHome = [Environment]::GetEnvironmentVariable('CODEX_HOME')
    if (-not [string]::IsNullOrWhiteSpace($envHome)) { return $envHome }
    $profileDir = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ([string]::IsNullOrWhiteSpace($profileDir)) {
        $profileDir = [Environment]::GetFolderPath('UserProfile')
    }
    return (Join-Path $profileDir '.codex')
}

function Read-Utf8File {
    param([string]$Path)
    $enc = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    return [System.IO.File]::ReadAllText($Path, $enc)
}

function Write-Utf8File {
    param([string]$Path, [string]$Text)
    $enc = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Split-Lines {
    param([string]$Text)
    $nl = "`n"
    if ($Text.Contains("`r`n")) { $nl = "`r`n" }
    $parts = [System.Text.RegularExpressions.Regex]::Split($Text, $ReLineBreak)
    return @{ Lines = $parts; NL = $nl }
}

function New-LineList {
    param([string[]]$Lines)
    $list = New-Object -TypeName 'System.Collections.Generic.List[string]'
    if ($null -ne $Lines) { $list.AddRange([string[]]$Lines) }
    return $list
}

function Normalize-Lines {
    param([string[]]$Lines)
    $out = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($line in $Lines) {
        if ($line.Trim() -eq '' -and $out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq '') { continue }
        if ([regex]::IsMatch($line, $ReAnyTableHead) -and $out.Count -gt 0 -and $out[$out.Count - 1].Trim() -ne '') {
            $out.Add('')
        }
        $out.Add($line)
    }
    while ($out.Count -gt 0 -and $out[0].Trim() -eq '') { $out.RemoveAt(0) }
    while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq '') { $out.RemoveAt($out.Count - 1) }
    $out.Add('')
    return $out.ToArray()
}

function Get-ProviderBlockLines {
    param([string]$Key)
    return @(
        '[model_providers.deepseek]',
        'name = "deepseek"',
        ('base_url = "' + $DsBaseUrl + '"'),
        ('wire_api = "' + $DsWireApi + '"'),
        ('experimental_bearer_token = "' + $Key + '"')
    )
}

# ------------------------------------------------------------------ 文本变换（纯函数，自检直接调用）

function Set-ProviderBlockLines {
    param([string[]]$Lines, [string]$Key)
    $list = New-LineList -Lines $Lines
    $block = [string[]](Get-ProviderBlockLines -Key $Key)
    $head = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ([regex]::IsMatch($list[$i], $ReProviderHead)) { $head = $i; break }
    }
    if ($head -lt 0) {
        while ($list.Count -gt 0 -and $list[$list.Count - 1].Trim() -eq '') { $list.RemoveAt($list.Count - 1) }
        $list.Add('')
        $list.AddRange($block)
        return $list.ToArray()
    }
    $end = $list.Count
    for ($j = $head + 1; $j -lt $list.Count; $j++) {
        if ([regex]::IsMatch($list[$j], $ReAnyTableHead)) { $end = $j; break }
    }
    $list.RemoveRange($head, $end - $head)
    $list.InsertRange($head, $block)
    return $list.ToArray()
}

function Remove-TrioLines {
    param([string[]]$Lines)
    $out = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($line in $Lines) {
        if ([regex]::IsMatch($line, $ReModelAny)) { continue }
        if ([regex]::IsMatch($line, $ReProviderAny)) { continue }
        if ([regex]::IsMatch($line, $ReCatalogAny)) { continue }
        $out.Add($line)
    }
    return $out.ToArray()
}

function Insert-TrioLines {
    param([string[]]$Lines, [string]$CatalogValue, [string]$Remembered)
    $block = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $block.Add(('model = "' + $DsModel + '"'))
    $block.Add(('model_provider = "' + $DsProviderName + '"'))
    $block.Add(('model_catalog_json = "' + $CatalogValue + '"'))
    if ($Remembered -ne '') { $block.Add(('# model = "' + $Remembered + '"   # GPT 通道时自动恢复')) }
    $list = New-LineList -Lines $Lines
    $first = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        $trimmed = $list[$i].Trim()
        if ($trimmed -ne '' -and -not $trimmed.StartsWith('#')) { $first = $i; break }
    }
    if ($first -lt 0) { $list.AddRange($block.ToArray()) } else { $list.InsertRange($first, $block.ToArray()) }
    return $list.ToArray()
}

function Find-RememberedGptModel {
    param([string[]]$Lines)
    $active = ''
    $commented = ''
    foreach ($line in $Lines) {
        $m = [regex]::Match($line, $ReModelActiveValue)
        if ($m.Success -and $m.Groups[1].Value -ne $DsModel) { $active = $m.Groups[1].Value; continue }
        $m2 = [regex]::Match($line, $ReModelCommentedValue)
        if ($m2.Success -and $m2.Groups[1].Value -ne $DsModel) { $commented = $m2.Groups[1].Value }
    }
    if ($active -ne '') { return $active }
    return $commented
}

function ConvertTo-DeepSeekText {
    param([string]$Text, [string]$Key, [string]$CatalogValue)
    $split = Split-Lines -Text $Text
    $lines = [string[]]$split.Lines
    $remembered = Find-RememberedGptModel -Lines $lines
    $lines = [string[]](Set-ProviderBlockLines -Lines $lines -Key $Key)
    $lines = [string[]](Remove-TrioLines -Lines $lines)
    $lines = [string[]](Insert-TrioLines -Lines $lines -CatalogValue $CatalogValue -Remembered $remembered)
    $lines = [string[]](Normalize-Lines -Lines $lines)
    return ($lines -join $split.NL)
}

function ConvertTo-GptText {
    param([string]$Text)
    $split = Split-Lines -Text $Text
    $out = New-Object -TypeName 'System.Collections.Generic.List[string]'
    foreach ($line in [string[]]$split.Lines) {
        if ([regex]::IsMatch($line, $ReModelDsActive)) {
            $out.Add('# model = "deepseek-flash"')
        }
        elseif ([regex]::IsMatch($line, $ReProviderDsActive)) {
            $out.Add('# model_provider = "deepseek"')
        }
        elseif ([regex]::IsMatch($line, $ReCatalogActive)) {
            $out.Add('# ' + $line.Trim())
        }
        else {
            $m = [regex]::Match($line, $ReModelCommentedValue)
            if ($m.Success -and $m.Groups[1].Value -ne $DsModel) {
                $out.Add('model = "' + $m.Groups[1].Value + '"')
            }
            else {
                $out.Add($line)
            }
        }
    }
    return ($out.ToArray() -join $split.NL)
}

function Remove-ProviderBlockText {
    param([string]$Text)
    $split = Split-Lines -Text $Text
    $list = New-LineList -Lines ([string[]]$split.Lines)
    $head = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ([regex]::IsMatch($list[$i], $ReProviderHead)) { $head = $i; break }
    }
    if ($head -lt 0) { return $Text }
    $end = $list.Count
    for ($j = $head + 1; $j -lt $list.Count; $j++) {
        if ([regex]::IsMatch($list[$j], $ReAnyTableHead)) { $end = $j; break }
    }
    $list.RemoveRange($head, $end - $head)
    $lines = [string[]](Normalize-Lines -Lines $list.ToArray())
    return ($lines -join $split.NL)
}

function Test-IsDeepSeekText {
    param([string]$Text)
    foreach ($line in [System.Text.RegularExpressions.Regex]::Split($Text, $ReLineBreak)) {
        if ([regex]::IsMatch($line, $ReModelDsActive)) { return $true }
        if ([regex]::IsMatch($line, $ReProviderDsActive)) { return $true }
    }
    return $false
}

# ------------------------------------------------------------------ 配置读写

function Get-DeepSeekKey {
    $candidates = @(
        (Join-Path $ScriptDir 'deepseek\deepseek-key.txt'),
        (Join-Path $ScriptDir 'deepseek-key.txt'),
        (Join-Path $InstallDir 'deepseek\deepseek-key.txt')
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            foreach ($line in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
                $t = $line.Trim()
                if ($t -eq '' -or $t.StartsWith('#')) { continue }
                return $t
            }
        }
    }
    if (Test-Path -LiteralPath $ConfigPath) {
        $m = [regex]::Match((Read-Utf8File -Path $ConfigPath), 'experimental_bearer_token\s*=\s*"([^"]+)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return ''
}

function Format-Secret {
    param([string]$Secret)
    if ($Secret.Length -le 10) { return '(已配置)' }
    return ($Secret.Substring(0, 6) + '...' + $Secret.Substring($Secret.Length - 4))
}

function New-ConfigBackup {
    param([string]$Tag)
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return '' }
    if (-not (Test-Path -LiteralPath $BackupDir)) { [void](New-Item -ItemType Directory -Path $BackupDir -Force) }
    $dest = Join-Path $BackupDir ('config.toml.bak-' + $Tag + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Copy-Item -LiteralPath $ConfigPath -Destination $dest -Force
    return $dest
}

function Get-BackupList {
    if (-not (Test-Path -LiteralPath $BackupDir)) { return @() }
    return @(Get-ChildItem -LiteralPath $BackupDir -Filter 'config.toml.bak-*' -File | Sort-Object LastWriteTime -Descending)
}

# ------------------------------------------------------------------ 输出

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host '==========================================' -ForegroundColor DarkGray
    Write-Host ('  ' + $Text) -ForegroundColor Cyan
    Write-Host '==========================================' -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Text)
    Write-Host ('  [OK] ' + $Text) -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host ('  [!] ' + $Text) -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Text)
    Write-Host ('  - ' + $Text)
}

# ------------------------------------------------------------------ 动作

function Invoke-SwitchDeepSeek {
    param([switch]$Quiet)
    $key = Get-DeepSeekKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Warn '没有找到 DeepSeek API Key，先看 使用说明.md 里的「改 API Key」一节。'
        return $false
    }
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Warn ('找不到配置文件：' + $ConfigPath)
        Write-Warn '请先安装并登录一次 Codex 桌面版，或者用 -Mode install 创建。'
        return $false
    }
    $before = Read-Utf8File -Path $ConfigPath
    $after = ConvertTo-DeepSeekText -Text $before -Key $key -CatalogValue $CatalogTomlValue
    if ($after -eq $before) {
        Write-Ok '配置本来就是 DeepSeek 通道，没有改动。'
        return $true
    }
    $backup = New-ConfigBackup -Tag 'deepseek'
    Write-Utf8File -Path $ConfigPath -Text $after
    if (-not $Quiet) {
        Write-Head '已切到 DeepSeek 通道'
        Write-Step ('配置文件：' + $ConfigPath)
        Write-Step ('备份：' + $backup)
        Write-Step ('模型：' + $DsModel + '（catalog: ' + $CatalogPath + '）')
        Write-Host ''
        Write-Host '  请完全退出并重新打开 Codex 应用后生效。' -ForegroundColor White
    }
    return $true
}

function Invoke-SwitchGpt {
    param([switch]$Quiet)
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Warn ('找不到配置文件：' + $ConfigPath)
        return $false
    }
    $before = Read-Utf8File -Path $ConfigPath
    $after = ConvertTo-GptText -Text $before
    if ($after -eq $before) {
        Write-Ok '配置本来就是 GPT 通道，没有改动。'
        return $true
    }
    $backup = New-ConfigBackup -Tag 'gpt'
    Write-Utf8File -Path $ConfigPath -Text $after
    if (-not $Quiet) {
        Write-Head '已切到 GPT 通道（ChatGPT 登录）'
        Write-Step ('配置文件：' + $ConfigPath)
        Write-Step ('备份：' + $backup)
        Write-Host ''
        Write-Host '  请完全退出并重新打开 Codex 应用后生效。' -ForegroundColor White
    }
    return $true
}

function Get-ChannelName {
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return '未知' }
    if (Test-IsDeepSeekText -Text (Read-Utf8File -Path $ConfigPath)) { return 'DeepSeek' }
    return 'GPT'
}

function Show-Status {
    Write-Head 'Codex 通道状态'
    $channel = Get-ChannelName
    $color = 'Green'
    if ($channel -eq 'DeepSeek') { $color = 'Magenta' }
    if ($channel -eq '未知') { $color = 'Yellow' }
    Write-Host ('  当前通道：' + $channel) -ForegroundColor $color
    Write-Host ''
    Write-Step ('codex 目录：' + $CodexRoot)
    Write-Step ('配置文件：' + $ConfigPath + '  ' + (Test-Path -LiteralPath $ConfigPath))
    if (Test-Path -LiteralPath $ConfigPath) {
        $text = Read-Utf8File -Path $ConfigPath
        foreach ($probe in @('model', 'model_provider', 'model_catalog_json')) {
            $hits = @()
            foreach ($line in [System.Text.RegularExpressions.Regex]::Split($text, $ReLineBreak)) {
                if ([regex]::IsMatch($line, ('^\s*#?\s*' + $probe + '\s*='))) { $hits += $line.Trim() }
            }
            if ($hits.Count -eq 0) { Write-Step ($probe + '：未出现') }
            else { foreach ($h in $hits) { Write-Step ($probe + '：' + $h) } }
        }
        if ([regex]::IsMatch($text, $ReProviderHead, 'Multiline')) { Write-Step 'provider 段：已存在' }
        else { Write-Step 'provider 段：缺失（切到 DeepSeek 时会自动写入）' }
    }
    Write-Step ('模型目录：' + $CatalogPath + '  ' + (Test-Path -LiteralPath $CatalogPath))
    $key = Get-DeepSeekKey
    if ([string]::IsNullOrWhiteSpace($key)) { Write-Step 'API Key：缺失' }
    else { Write-Step ('API Key：' + (Format-Secret -Secret $key)) }
    $backups = Get-BackupList
    Write-Step ('备份数量：' + $backups.Count)
    if ($backups.Count -gt 0) { Write-Step ('最近备份：' + $backups[0].Name) }
}

function Invoke-Restore {
    Write-Head '恢复配置备份'
    $backups = Get-BackupList
    if ($backups.Count -eq 0) {
        Write-Warn ('没有找到备份：' + $BackupDir)
        return
    }
    $newest = $backups[0]
    Write-Step ('将恢复：' + $newest.Name + '  (' + $newest.LastWriteTime + ')')
    $keep = New-ConfigBackup -Tag 'prerestore'
    Copy-Item -LiteralPath $newest.FullName -Destination $ConfigPath -Force
    Write-Ok '恢复完成。'
    Write-Step ('恢复前的配置已另存：' + $keep)
    Write-Host ''
    Write-Host '  请完全退出并重新打开 Codex 应用后生效。' -ForegroundColor White
}

function Invoke-Uninstall {
    Write-Head '停用 DeepSeek 通道'
    if (Test-Path -LiteralPath $ConfigPath) {
        $before = Read-Utf8File -Path $ConfigPath
        $after = Remove-ProviderBlockText -Text (ConvertTo-GptText -Text $before)
        $backup = New-ConfigBackup -Tag 'uninstall'
        Write-Utf8File -Path $ConfigPath -Text $after
        Write-Ok '已注释掉 DeepSeek 三行并移除 provider 段。'
        Write-Step ('备份：' + $backup)
    }
    else {
        Write-Warn '没有找到 config.toml，跳过。'
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    foreach ($name in @('切到DeepSeek.lnk', '切到GPT.lnk', '一键切换模型.lnk')) {
        $lnk = Join-Path $desktop $name
        if (Test-Path -LiteralPath $lnk) {
            Remove-Item -LiteralPath $lnk -Force
            Write-Ok ('已删除桌面图标：' + $name)
        }
    }
    Write-Host ''
    Write-Step ('models.json 仍在：' + $CatalogPath)
    Write-Step ('脚本目录可以手动删除：' + $InstallDir)
}

function Copy-PackageToInstallDir {
    if (-not (Test-Path -LiteralPath $InstallDir)) { [void](New-Item -ItemType Directory -Path $InstallDir -Force) }
    $items = @('CodexSwitch.ps1', '切到DeepSeek.bat', '切到GPT.bat', '一键切换.bat', '查看当前通道.bat', '恢复上次备份.bat', '使用说明.md')
    foreach ($item in $items) {
        $src = Join-Path $ScriptDir $item
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $InstallDir -Force }
    }
    $subDir = Join-Path $InstallDir 'deepseek'
    if (-not (Test-Path -LiteralPath $subDir)) { [void](New-Item -ItemType Directory -Path $subDir -Force) }
    $srcDeep = Join-Path $ScriptDir 'deepseek'
    if (Test-Path -LiteralPath (Join-Path $srcDeep 'models.json')) {
        Copy-Item -LiteralPath (Join-Path $srcDeep 'models.json') -Destination $subDir -Force
    }
    if (Test-Path -LiteralPath (Join-Path $srcDeep 'deepseek-key.txt')) {
        Copy-Item -LiteralPath (Join-Path $srcDeep 'deepseek-key.txt') -Destination $subDir -Force
    }
    $srcIcons = Join-Path $ScriptDir 'icons'
    if (Test-Path -LiteralPath $srcIcons) {
        $dstIcons = Join-Path $InstallDir 'icons'
        if (-not (Test-Path -LiteralPath $dstIcons)) { [void](New-Item -ItemType Directory -Path $dstIcons -Force) }
        Copy-Item -LiteralPath (Join-Path $srcIcons '*.ico') -Destination $dstIcons -Force
    }
}

function New-DesktopShortcut {
    param([string]$LinkName, [string]$BatName, [string]$IconName, [string]$Description)
    $desktop = [Environment]::GetFolderPath('Desktop')
    $linkPath = Join-Path $desktop $LinkName
    $target = Join-Path $InstallDir $BatName
    if (-not (Test-Path -LiteralPath $target)) { return $false }
    $icon = Join-Path (Join-Path $InstallDir 'icons') $IconName
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($linkPath)
    $lnk.TargetPath = $target
    $lnk.WorkingDirectory = $InstallDir
    if (Test-Path -LiteralPath $icon) { $lnk.IconLocation = $icon }
    $lnk.Description = $Description
    $lnk.Save()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    return $true
}

function Invoke-Install {
    Write-Head 'Codex 通道切换器 · 一次性安装'
    Write-Step ('脚本目录：' + $ScriptDir)
    Write-Step ('codex 目录：' + $CodexRoot)

    $running = @(Get-Process -Name 'ChatGPT', 'Codex' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        Write-Warn '检测到 Codex/ChatGPT 正在运行，安装会改 config.toml，建议先完全退出它。'
    }

    if (-not (Test-Path -LiteralPath $CodexRoot)) {
        [void](New-Item -ItemType Directory -Path $CodexRoot -Force)
        Write-Ok ('已创建目录：' + $CodexRoot)
    }
    if (-not (Test-Path -LiteralPath $BackupDir)) { [void](New-Item -ItemType Directory -Path $BackupDir -Force) }

    $catalogSrc = Join-Path (Join-Path $ScriptDir 'deepseek') 'models.json'
    if (Test-Path -LiteralPath $catalogSrc) {
        if (Test-Path -LiteralPath $CatalogPath) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            Copy-Item -LiteralPath $CatalogPath -Destination (Join-Path $BackupDir ('models.json.bak-' + $stamp)) -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -LiteralPath $catalogSrc -Destination $CatalogPath -Force
        Write-Ok ('已安装模型目录：' + $CatalogPath)
    }
    else {
        Write-Warn '包里没有 deepseek\models.json，跳过模型目录安装。'
    }

    Copy-PackageToInstallDir
    Write-Ok ('已复制脚本到：' + $InstallDir)

    if ($OnWindows) {
        $ok1 = New-DesktopShortcut -LinkName '切到DeepSeek.lnk' -BatName '切到DeepSeek.bat' -IconName 'deepseek.ico' -Description 'Codex 切到 DeepSeek 通道'
        $ok2 = New-DesktopShortcut -LinkName '切到GPT.lnk' -BatName '切到GPT.bat' -IconName 'gpt.ico' -Description 'Codex 切回 GPT 通道'
        $ok3 = New-DesktopShortcut -LinkName '一键切换模型.lnk' -BatName '一键切换.bat' -IconName 'switch.ico' -Description 'Codex 在 DeepSeek / GPT 之间一键切换'
        if ($ok1 -and $ok2 -and $ok3) { Write-Ok '已在桌面创建 3 个图标。' }
        else { Write-Warn '部分桌面图标没创建成功（在文件夹里直接双击 .bat 也可以）。' }
    }
    else {
        Write-Warn '当前不是 Windows，跳过桌面图标创建。'
    }

    Invoke-SwitchDeepSeek -Quiet | Out-Null
    $channel = Get-ChannelName
    Write-Host ''
    Write-Host ('  安装完成，当前通道：' + $channel) -ForegroundColor White
    Write-Host '  以后双击桌面上的「一键切换模型」即可来回切。' -ForegroundColor White
    Write-Host '  切换后请完全退出并重新打开 Codex 应用。' -ForegroundColor White
}

function Invoke-SelfTest {
    Write-Head '自检（不会改动你的配置）'
    $key = 'sk-SELFTEST-0123456789'
    $cat = 'C:/Users/test/.codex/models.json'
    $samples = @(
        @{ Name = '全新 Windows 配置'; Text = ("notify = []`nmodel = `"gpt-5.6-sol`"`nmodel_reasoning_effort = `"medium`"`n`n[desktop]`nlocaleOverride = `"zh-CN`"`n") },
        @{ Name = 'CRLF 换行'; Text = ("model = `"gpt-5.6-sol`"`r`n`r`n[desktop]`r`nlocaleOverride = `"zh-CN`"`r`n") },
        @{ Name = '空配置'; Text = '' },
        @{ Name = '只有注释'; Text = "# generated`n" },
        @{ Name = '已经是 DeepSeek'; Text = ("model = `"deepseek-flash`"`nmodel_provider = `"deepseek`"`nmodel_catalog_json = `"x`"`n`n[model_providers.deepseek]`nbase_url = `"https://api.deepseek.com/`"`n") }
    )
    $failed = 0
    foreach ($s in $samples) {
        $ds = ConvertTo-DeepSeekText -Text $s.Text -Key $key -CatalogValue $cat
        $back = ConvertTo-GptText -Text $ds
        $again = ConvertTo-DeepSeekText -Text $back -Key $key -CatalogValue $cat
        $checks = @(
            @{ Label = '切到 DeepSeek'; Pass = (Test-IsDeepSeekText -Text $ds) },
            @{ Label = 'provider 段唯一'; Pass = ([regex]::Matches($ds, $ReProviderHead, 'Multiline').Count -eq 1) },
            @{ Label = 'Key 已写入'; Pass = $ds.Contains($key) },
            @{ Label = '切回 GPT'; Pass = (-not (Test-IsDeepSeekText -Text $back)) },
            @{ Label = '往返稳定'; Pass = ($again -eq $ds) },
            @{ Label = '换行风格保留'; Pass = (($s.Text.Contains("`r`n") -eq $back.Contains("`r`n"))) }
        )
        $bad = @($checks | Where-Object { -not $_.Pass })
        if ($bad.Count -eq 0) { Write-Ok ($s.Name + '：全部通过') }
        else {
            $failed++
            Write-Warn ($s.Name + '：失败 -> ' + (($bad | ForEach-Object { $_.Label }) -join '、'))
            Write-Host ('    DeepSeek 结果：' + [Environment]::NewLine + $ds)
        }
    }
    Write-Host ''
    if ($failed -eq 0) { Write-Host '  自检全部通过。' -ForegroundColor Green }
    else { Write-Host ('  有 ' + $failed + ' 组失败，请把上面的输出发给我。') -ForegroundColor Red }
}

# ------------------------------------------------------------------ 主流程

$CodexRoot = Resolve-CodexRoot
$ConfigPath = Join-Path $CodexRoot 'config.toml'
$CatalogPath = Join-Path $CodexRoot 'models.json'
$CatalogTomlValue = $CatalogPath.Replace('\', '/')
$InstallDir = Join-Path $CodexRoot 'deepseek-switch'
$BackupDir = Join-Path $CodexRoot 'deepseek-switch-backups'

try {
    switch ($Mode) {
        'install' { Invoke-Install }
        'deepseek' { [void](Invoke-SwitchDeepSeek) }
        'gpt' { [void](Invoke-SwitchGpt) }
        'toggle' {
            $channel = Get-ChannelName
            if ($channel -eq 'DeepSeek') {
                Write-Host '  当前是 DeepSeek 通道，切换到 GPT …' -ForegroundColor DarkGray
                [void](Invoke-SwitchGpt)
            }
            else {
                Write-Host ('  当前是 ' + $channel + ' 通道，切换到 DeepSeek …') -ForegroundColor DarkGray
                [void](Invoke-SwitchDeepSeek)
            }
        }
        'status' { Show-Status }
        'restore' { Invoke-Restore }
        'uninstall' { Invoke-Uninstall }
        'selftest' { Invoke-SelfTest }
    }
}
catch {
    Write-Host ''
    Write-Host ('  出错了：' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('  位置：' + $_.InvocationInfo.PositionMessage) -ForegroundColor DarkGray
    Write-Host '  切换类动作只在最后一步整体写回 config.toml，没写完就不会留下半成品。' -ForegroundColor DarkGray
    Write-Host '  如果不放心，双击「恢复上次备份.bat」回滚。' -ForegroundColor DarkGray
}

if (-not $NoPause) {
    try {
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            Write-Host ''
            [void](Read-Host '按回车键关闭窗口')
        }
    }
    catch { }
}
