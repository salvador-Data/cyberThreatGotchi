# Dot-source at top of CTG orchestrators for faster cold start (no security weakening).
$ProgressPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'

# Avoid implicit progress bars from Copy-Item, Invoke-WebRequest, etc.
if (-not (Get-Variable -Name CtgShellFastApplied -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CtgShellFastApplied = $true
}

# Documented skip list — orchestrators must not Import-Module these unless required.
$script:CtgShellHeavyModuleSkip = @(
    'Az', 'AzureRM', 'Microsoft.Graph', 'ExchangeOnlineManagement',
    'VMware.Vim', 'VMware.PowerCLI', 'AWS.Tools.Common', 'ImportExcel'
)
