# 上传文件到 SL1680
# ⚠️ 已知坑: .NET Process.StandardInput 会在开头注入 3 字节 UTF-8 BOM
#    文本文件 python 能容忍，但**二进制会被破坏**(ELF头坏 -> Exec format error)
#    判据: 板上文件大小 = 本地 +3。所以传完必须在板上剥 BOM:
#      d=open(p,'rb').read()
#      if d[:3]==b'\xef\xbb\xbf': open(p,'wb').write(d[3:])
# 用法: powershell -File wgput.ps1 <本地文件> <板上路径>
param(
    [Parameter(Mandatory=$true)][string]$LocalFile,
    [Parameter(Mandatory=$true)][string]$RemotePath
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"

$bytes = [System.IO.File]::ReadAllBytes($LocalFile)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\Windows\System32\OpenSSH\ssh.exe"
$psi.Arguments = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL ' +
                 '-o ConnectTimeout=45 -o ServerAliveInterval=8 -o ServerAliveCountMax=6 ' +
                 '-J root@192.168.5.1 root@192.168.8.186 ' +
                 '"cat > ' + $RemotePath + '"'
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

$p = [System.Diagnostics.Process]::Start($psi)
$p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
$p.StandardInput.BaseStream.Flush()
$p.StandardInput.Close()
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()

if ($stdout.Trim()) { Write-Output $stdout.Trim() }
$errLines = $stderr -split "`n" | Where-Object { $_ -and $_ -notmatch "Permanently added|known hosts" }
if ($errLines) { $errLines | ForEach-Object { Write-Output $_.Trim() } }
Write-Output ("exit={0}  ({1} bytes -> {2})" -f $p.ExitCode, $bytes.Length, $RemotePath)
