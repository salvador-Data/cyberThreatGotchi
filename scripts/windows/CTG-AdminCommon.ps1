# Dot-source canonical repo path helpers for all CTG windows scripts.
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
function Test-CtgIsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
