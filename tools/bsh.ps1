# 直连把本地 shell 脚本送到 SL1680 执行（家庭网络同网段，不走跳板）
# base64 内联，避开引号/中文被 PowerShell 或 cmd 吃掉的问题
# 板子 busybox 没有 base64 命令 -> 用 python3 解码
#
# 用法: powershell -File bsh.ps1 <本地脚本路径>
# 出门在外走隧道时用 wgsh.ps1
param([Parameter(Mandatory=$true)][string]$ScriptFile)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
$raw = [System.IO.File]::ReadAllText($ScriptFile) -replace "`r`n", "`n"
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($raw))
$remote = "echo $b64 | python3 -c 'import sys,base64,os; os.write(1, base64.b64decode(sys.stdin.read()))' | sh"
& "C:\Windows\System32\OpenSSH\ssh.exe" `
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
    -o ConnectTimeout=20 -o ServerAliveInterval=10 -o ServerAliveCountMax=6 `
    root@192.168.5.126 $remote 2>&1 |
    Where-Object { $_ -notmatch "Permanently added|known hosts" }
