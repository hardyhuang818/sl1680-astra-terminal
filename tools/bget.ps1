# 直连从 SL1680 下载文件（家庭网络同网段，二进制安全）
# 用法: powershell -File bget.ps1 <板端路径> <本地路径>
param(
    [Parameter(Mandatory=$true)][string]$Remote,
    [Parameter(Mandatory=$true)][string]$Local
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName  = "C:\Windows\System32\OpenSSH\ssh.exe"
$psi.Arguments = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=20 " +
                 "root@192.168.5.126 `"cat '$Remote'`""
$psi.UseShellExecute        = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true

$p = [System.Diagnostics.Process]::Start($psi)
$fs = [System.IO.File]::Create($Local)
$p.StandardOutput.BaseStream.CopyTo($fs)
$fs.Close()
$err = $p.StandardError.ReadToEnd()
$p.WaitForExit()
if ($err -and $err -notmatch "Permanently added|known hosts") { Write-Output $err.Trim() }
Write-Output ("exit={0}  ({1} bytes <- {2})" -f $p.ExitCode, (Get-Item $Local).Length, $Remote)
