# 从 SL1680 下载文件（读 ssh stdout 原始字节流，二进制安全）
# 用法: powershell -File wgget.ps1 <板上路径> <本地路径>
param(
    [Parameter(Mandatory=$true)][string]$RemotePath,
    [Parameter(Mandatory=$true)][string]$LocalFile
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\Windows\System32\OpenSSH\ssh.exe"
$psi.Arguments = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL ' +
                 '-o ConnectTimeout=45 -o ServerAliveInterval=8 ' +
                 '-J root@192.168.5.1 root@192.168.8.186 ' +
                 '"cat ' + $RemotePath + '"'
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)
$ms = New-Object System.IO.MemoryStream
$p.StandardOutput.BaseStream.CopyTo($ms)
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
[System.IO.File]::WriteAllBytes($LocalFile, $ms.ToArray())
$ms.Close()

$errLines = $stderr -split "`n" | Where-Object { $_ -and $_ -notmatch "Permanently added|known hosts" }
if ($errLines) { $errLines | ForEach-Object { Write-Output $_.Trim() } }
Write-Output ("exit={0}  ({1} bytes <- {2})" -f $p.ExitCode, (Get-Item $LocalFile).Length, $RemotePath)
