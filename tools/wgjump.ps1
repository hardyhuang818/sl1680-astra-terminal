# Run a script on the home OpenWrt jump host only (do NOT hop to the board).
# Use when the board is unreachable: tells you whether the tunnel died or the board did.
#
# Why a script file and not a command string:
#   powershell -File re-splits args on whitespace, so outer quotes are lost and
#   things like -w / $(...) get eaten by PowerShell's own parser.
# Why cmd.exe does the redirect:
#   Windows PowerShell 5.1 Get-Content defaults to ANSI and mangles UTF-8, then
#   re-encodes on the way out. "cmd /c ... < file" is byte-exact, no re-encoding.
#
# Usage: powershell -File wgjump.ps1 <local-script-path>
param([Parameter(Mandatory=$true)][string]$ScriptPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:SSH_ASKPASS = "$here\askpass_wg.cmd"
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "localhost:0"
if (-not (Test-Path $ScriptPath)) { Write-Output "script not found: $ScriptPath"; exit 1 }

# strip UTF-8 BOM and normalise CRLF -> LF, at the byte level
$bytes = [System.IO.File]::ReadAllBytes($ScriptPath)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
}
$out = New-Object System.Collections.Generic.List[byte]
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x0D -and $i + 1 -lt $bytes.Length -and $bytes[$i+1] -eq 0x0A) { continue }
    $out.Add($bytes[$i])
}
$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($tmp, $out.ToArray())

& cmd.exe /c "`"C:\Windows\System32\OpenSSH\ssh.exe`" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ConnectTimeout=30 root@192.168.5.1 `"sh -s`" < `"$tmp`" 2>&1" |
    Where-Object { $_ -notmatch "Permanently added|known hosts" }

Remove-Item $tmp -ErrorAction SilentlyContinue
