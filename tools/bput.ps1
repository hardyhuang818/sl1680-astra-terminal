# 直连上传文件到 SL1680（家庭网络同网段）
# ⚠️ .NET StandardInput 会注入 3 字节 UTF-8 BOM：文本没事，二进制直接废。
#    判据：板上大小 = 本地 +3。传完在板上剥掉即可。
# 用法: powershell -File bput.ps1 <本地文件> <板端路径>
param(
    [Parameter(Mandatory=$true)][string]$Local,
    [Parameter(Mandatory=$true)][string]$Remote
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
if (-not (Test-Path $Local)) { Write-Output "找不到: $Local"; exit 1 }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName  = "C:\Windows\System32\OpenSSH\ssh.exe"
$psi.Arguments = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=20 " +
                 "root@192.168.5.126 `"cat > '$Remote'`""
$psi.UseShellExecute        = $false
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardError  = $true

$p = [System.Diagnostics.Process]::Start($psi)
$bytes = [System.IO.File]::ReadAllBytes($Local)
$p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
$p.StandardInput.BaseStream.Flush()
$p.StandardInput.Close()
$err = $p.StandardError.ReadToEnd()
$p.WaitForExit()
if ($err -and $err -notmatch "Permanently added|known hosts") { Write-Output $err.Trim() }
Write-Output "exit=$($p.ExitCode)  ($($bytes.Length) bytes -> $Remote)"
