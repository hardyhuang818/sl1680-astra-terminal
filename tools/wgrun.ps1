# 在 SL1680 上执行命令（经家里 OpenWrt 跳板 + WireGuard 隧道）
# 拓扑: PC(192.168.5.166) -> 家OpenWrt 192.168.5.1 -> wg0 -> BE3600 -> SL1680 192.168.8.186
# 注意: paramiko 连不上跳板(no acceptable ciphers)，必须用 native ssh 的 -J
# 用法: powershell -File wgrun.ps1 "命令"
param([Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)][string[]]$Cmd)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
$remote = ($Cmd -join ' ')
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
