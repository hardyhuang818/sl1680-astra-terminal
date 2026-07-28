# 直连 SL1680 执行命令（家庭网络，同网段，不走跳板/WireGuard）
# 板子: 192.168.5.126   PC: 192.168.5.166
# 出门在外走隧道时改用 wgrun.ps1（-J root@192.168.5.1 root@192.168.8.186）
#
# 用法: powershell -File brun.ps1 "命令"
param([Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)][string[]]$Cmd)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
$remote = ($Cmd -join ' ')
& "C:\Windows\System32\OpenSSH\ssh.exe" `
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
    -o ConnectTimeout=20 root@192.168.5.126 $remote 2>&1 |
    Where-Object { $_ -notmatch "Permanently added|known hosts" }
