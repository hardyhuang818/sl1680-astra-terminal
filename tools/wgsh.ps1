# 把本地 shell 脚本送到 SL1680 执行（base64 内联，避开引号/中文被吃的问题）
# 板子 busybox 没有 base64 命令 -> 用 python3 解码
# 用法: powershell -File wgsh.ps1 <本地脚本路径>
param([Parameter(Mandatory=$true)][string]$ScriptFile)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
$raw = [System.IO.File]::ReadAllText($ScriptFile) -replace "`r`n", "`n"
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($raw))
$remote = "echo $b64 | python3 -c 'import sys,base64,os; os.write(1, base64.b64decode(sys.stdin.read()))' | sh"
$ok = $false
for ($i = 1; $i -le 3 -and -not $ok; $i++) {
    $out = & "C:\Windows\System32\OpenSSH\ssh.exe" `
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
        -o ConnectTimeout=45 -o ServerAliveInterval=8 -o ServerAliveCountMax=6 `
        -J root@192.168.5.1 root@192.168.8.186 $remote 2>&1
    if ($out -match "banner exchange|timed out|Connection closed|kex_exchange") {
        Write-Output "[retry $i : tunnel jitter]"; Start-Sleep -Seconds 5
    } else { $ok = $true }
}
$out | Where-Object { $_ -notmatch "Permanently added|known hosts" }
