param(
    [ValidateSet('Install', 'Start', 'Check', 'ASR')]
    [string]$Mode = 'Install'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$StudioExitCode = 0
$TranscriptStarted = $false

try {
    Set-Location -LiteralPath $PSScriptRoot
    $LogPath = Join-Path $PSScriptRoot 'install.log'
    if ($Mode -eq 'Start') { $LogPath = Join-Path $PSScriptRoot 'start.log' }
    Start-Transcript -LiteralPath $LogPath -Append -Force | Out-Null
    $TranscriptStarted = $true
    Write-Host '视频重创工作台 v0.2.5' -ForegroundColor Cyan
    Write-Host ('操作：' + $Mode + '；时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    Write-Host ('日志：' + $LogPath)
    if (-not [Environment]::Is64BitOperatingSystem) { throw '本安装包需要 64 位 Windows。' }
    . (Join-Path $PSScriptRoot 'scripts\windows_install_common.ps1')
    $VenvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'

    if ($Mode -eq 'Check') {
        if (-not (Get-StudioPythonInfo -Executable $VenvPython)) {
            throw '此设备尚未准备好运行环境。双击启动工作台可自动安装。'
        }
        Invoke-StudioChecked -Executable $VenvPython -Arguments @((Join-Path $PSScriptRoot 'scripts\check_environment.py'))
    } else {
        Write-Host '检查本机环境，请稍候。'
        if ($Mode -eq 'Install' -or -not (Test-StudioEnvironment -Root $PSScriptRoot)) {
            Install-StudioEnvironment -Root $PSScriptRoot
        } else {
            Write-Host '本机环境可用，直接复用。'
        }
        if ($Mode -eq 'ASR') {
            Write-Host '安装可选语音识别；所需下载较大，完成后在设置中启用。'
            Invoke-StudioChecked -Executable $VenvPython -Arguments @('-m', 'pip', 'install', '--disable-pip-version-check', '--retries', '3', '--timeout', '60', '-r', (Join-Path $PSScriptRoot 'requirements-asr.txt'))
            Invoke-StudioChecked -Executable $VenvPython -Arguments @('-c', 'import faster_whisper; print("Speech recognition: ready")')
            Write-Host '语音识别安装完成。' -ForegroundColor Green
        } elseif ($Mode -eq 'Start') {
            Write-Host '正在打开工作台。请保留此后台窗口，退出后台可按 Ctrl+C。' -ForegroundColor Green
            Invoke-StudioChecked -Executable $VenvPython -Arguments @('-u', (Join-Path $PSScriptRoot 'launcher.py'))
        } else {
            Write-Host '安装和运行检查完成。双击 启动工作台.bat 即可使用。' -ForegroundColor Green
        }
    }
} catch {
    $StudioExitCode = 1
    Write-Host ('未完成：' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ($_ | Out-String)
    Write-Host '请保留本窗口及 install.log / start.log；Python 安装详情保存在 logs 文件夹。'
} finally {
    if ($TranscriptStarted) { Stop-Transcript | Out-Null }
}
exit $StudioExitCode
