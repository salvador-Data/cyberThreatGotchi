# CTG shell fast path — sourced from PowerShell profile (see Optimize-CtgShellPerformance.ps1 -ApplySafe).
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'

function ctg {
    Set-Location (Join-Path $env:USERPROFILE 'Programs\Hacker Planet LLC\cyberThreatGotchi')
}

function ctg-programs {
    Set-Location (Join-Path $env:USERPROFILE 'Programs\Hacker Planet LLC')
}

# Heavy modules CTG orchestrators do not auto-import (documented skip list).
$script:CtgShellHeavyModuleSkip = @(
    'Az', 'AzureRM', 'Microsoft.Graph', 'ExchangeOnlineManagement',
    'VMware.Vim', 'VMware.PowerCLI', 'AWS.Tools.Common', 'ImportExcel'
)
