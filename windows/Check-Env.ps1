# Codex 切换器环境检查（只读，不改任何文件）
# 适用：Windows 10/11 + PowerShell 5.1

$ErrorActionPreference = 'Continue'
$script:OkCount = 0
$script:WarnCount = 0
$script:FailCount = 0

function Write-Item {
    param([string]$Status, [string]$Label, [string]$Detail)
    switch ($Status) {
        'OK'   { Write-Host ('[通过] ' + $Label + '  ' + $Detail) -ForegroundColor Green; $script:OkCount++ }
        'WARN' { Write-Host ('[注意] ' + $Label + '  ' + $Detail) -ForegroundColor Yellow; $script:WarnCount++ }
        default { Write-Host ('[失败] ' + $Label + '  ' + $Detail) -ForegroundColor Red; $script:FailCount++ }
    }
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ' Codex 切换器 · 环境检查（只读）' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''

$ScriptDir = Split-Path -Parent $PSCommandPath
$CodexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$ConfigPath = Join-Path $CodexRoot 'config.toml'
$CatalogPath = Join-Path $CodexRoot 'models.json'
$KeyPath = Join-Path $ScriptDir 'deepseek\deepseek-key.txt'

Write-Host ('检查时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ('Codex 目录：' + $CodexRoot)
Write-Host ''

# 1 操作系统
$os = [Environment]::OSVersion.Version
if ($os.Major -ge 10) {
    Write-Item 'OK' '操作系统' ('Windows ' + $os.Major + '.' + $os.Minor)
} else {
    Write-Item 'FAIL' '操作系统' '需要 Windows 10 或 Windows 11'
}

# 2 PowerShell
$psv = $PSVersionTable.PSVersion
if ($psv.Major -ge 5) {
    Write-Item 'OK' 'PowerShell' ('版本 ' + $psv.ToString())
} else {
    Write-Item 'FAIL' 'PowerShell' ('版本 ' + $psv.ToString() + '，需要 5.1 或更新')
}

# 3 代码执行策略
$policy = Get-ExecutionPolicy
if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
    Write-Item 'WARN' '执行策略' ($policy + '；.bat 已带 -ExecutionPolicy Bypass，通常仍可运行')
} else {
    Write-Item 'OK' '执行策略' $policy
}

# 4 Codex 配置目录
if (Test-Path -LiteralPath $CodexRoot) {
    Write-Item 'OK' '配置目录' '已存在'
} else {
    Write-Item 'FAIL' '配置目录' '不存在；请先安装并打开一次 Codex 桌面版并登录'
}

# 5 config.toml
if (Test-Path -LiteralPath $ConfigPath) {
    Write-Item 'OK' 'config.toml' '已存在'
} else {
    Write-Item 'FAIL' 'config.toml' '缺失；请先登录一次 Codex 桌面版'
}

# 6 models.json
if (Test-Path -LiteralPath $CatalogPath) {
    $minVersion = ''
    try {
        $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
        if ($catalog.PSObject.Properties.Name -contains 'minimal_client_version') {
            $minVersion = [string]$catalog.minimal_client_version
        }
    } catch {
        $minVersion = ''
    }
    if ($minVersion -ne '') {
        Write-Item 'OK' 'models.json' ('已存在，要求客户端 >= ' + $minVersion)
    } else {
        Write-Item 'OK' 'models.json' '已存在'
    }
} else {
    Write-Item 'WARN' 'models.json' '缺失；双击「一键安装.bat」会安装'
}

# 7 DeepSeek Key
$key = ''
if (Test-Path -LiteralPath $KeyPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($KeyPath, [System.Text.Encoding]::UTF8)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $key = $t
        break
    }
}
if ($key -eq '') {
    Write-Item 'WARN' 'DeepSeek Key' '未填写；打开 deepseek\deepseek-key.txt 粘贴自己的 Key'
} elseif ($key.Length -lt 20) {
    Write-Item 'WARN' 'DeepSeek Key' '内容过短，确认粘贴的是完整 Key'
} else {
    Write-Item 'OK' 'DeepSeek Key' ($key.Substring(0, 6) + '...' + $key.Substring($key.Length - 4))
}

# 8 Codex 命令
$cmd = Get-Command codex -ErrorAction SilentlyContinue
if ($cmd -ne $null) {
    Write-Item 'OK' 'codex 命令' $cmd.Source
} else {
    Write-Item 'WARN' 'codex 命令' 'PATH 里没有 codex；只用桌面版可以忽略'
}

# 9 桌面应用
$programFiles = [Environment]::GetFolderPath('ProgramFiles')
$appDirs = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Codex'),
    (Join-Path $env:LOCALAPPDATA 'Codex'),
    (Join-Path $programFiles 'Codex')
)
$appFound = ''
foreach ($dir in $appDirs) {
    if ($dir -ne '' -and (Test-Path -LiteralPath $dir)) { $appFound = $dir; break }
}
if ($appFound -ne '') {
    Write-Item 'OK' 'Codex 桌面版' $appFound
} else {
    Write-Item 'WARN' 'Codex 桌面版' '常见安装目录未找到；若已安装可忽略'
}

# 10 已有 provider 段
if (Test-Path -LiteralPath $ConfigPath) {
    $hit = Select-String -LiteralPath $ConfigPath -Pattern '^\[model_providers\.deepseek\]' -Quiet
    if ($hit) {
        Write-Item 'OK' 'DeepSeek provider 段' '已存在'
    } else {
        Write-Item 'WARN' 'DeepSeek provider 段' '缺失；双击「一键安装.bat」会写入'
    }
}

Write-Host ''
Write-Host ('结果：通过 ' + $script:OkCount + '，注意 ' + $script:WarnCount + '，失败 ' + $script:FailCount) -ForegroundColor Cyan
if ($script:FailCount -gt 0) {
    Write-Host '先处理红色项目，再双击「一键安装.bat」。' -ForegroundColor Red
} elseif ($script:WarnCount -gt 0) {
    Write-Host '黄色项目不影响继续，按提示补齐即可。' -ForegroundColor Yellow
} else {
    Write-Host '环境检查全部通过，可以安装。' -ForegroundColor Green
}
Write-Host ''
