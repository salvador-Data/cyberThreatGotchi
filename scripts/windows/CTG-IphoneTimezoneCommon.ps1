# Shared helpers for iPhone timezone sync (authorized defensive lab use only).
# Reads gitignored Backups\iphone-location\timezone.json — never commit PII or coords.

. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

function Get-CtgIphoneTimezoneDir {
    return Join-Path $env:USERPROFILE 'Backups\iphone-location'
}

function Get-CtgIphoneTimezoneFile {
    param([switch] $AllowAlias)
    $dir = Get-CtgIphoneTimezoneDir
    $primary = Join-Path $dir 'timezone.json'
    if (Test-Path $primary) { return $primary }
    if ($AllowAlias) {
        $alias = Join-Path $dir 'iphone-timezone.json'
        if (Test-Path $alias) { return $alias }
    }
    return $primary
}

function Get-CtgDailyUtmsAlertStateFile {
    return Join-Path (Get-CtgIphoneTimezoneDir) 'daily-alert-state.json'
}

function Test-CtgIanaTimezoneId {
    param([string] $TimezoneId)
    if ([string]::IsNullOrWhiteSpace($TimezoneId)) { return $false }
    $tz = $TimezoneId.Trim()
    if ($tz -notmatch '^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)+$') { return $false }
    try {
        $null = [TimeZoneInfo]::FindSystemTimeZoneById($tz)
        return $true
    } catch {
        try {
            $winId = $null
            if ([TimeZoneInfo]::TryConvertIanaIdToWindowsId($tz, [ref]$winId)) {
                return $true
            }
        } catch { }
    }
    return $false
}

function Read-CtgIphoneTimezoneJson {
    param([switch] $AllowAlias)
    $path = Get-CtgIphoneTimezoneFile -AllowAlias:$AllowAlias
    if (-not (Test-Path $path)) {
        return $null
    }
    try {
        $raw = Get-Content -Path $path -Raw -Encoding utf8
        $obj = $raw | ConvertFrom-Json
        if (-not $obj) { return $null }
        $tz = [string]$obj.timezone
        if (-not (Test-CtgIanaTimezoneId -TimezoneId $tz)) {
            return [PSCustomObject]@{
                Path      = $path
                Valid     = $false
                Timezone  = $tz
                Updated   = [string]$obj.updated
                Error     = 'invalid IANA timezone string'
            }
        }
        return [PSCustomObject]@{
            Path      = $path
            Valid     = $true
            Timezone  = $tz.Trim()
            Updated   = [string]$obj.updated
            Latitude  = if ($null -ne $obj.lat) { [string]$obj.lat } else { '' }
            Longitude = if ($null -ne $obj.lon) { [string]$obj.lon } else { '' }
            Error     = ''
        }
    } catch {
        return [PSCustomObject]@{
            Path     = $path
            Valid    = $false
            Timezone = ''
            Updated  = ''
            Error    = $_.Exception.Message
        }
    }
}

function Get-CtgLocalTimeInTimezone {
    param([string] $TimezoneId)
    if (-not (Test-CtgIanaTimezoneId -TimezoneId $TimezoneId)) {
        throw "Invalid IANA timezone: $TimezoneId"
    }
    try {
        $tzInfo = [TimeZoneInfo]::FindSystemTimeZoneById($TimezoneId.Trim())
    } catch {
        $winId = $null
        if (-not [TimeZoneInfo]::TryConvertIanaIdToWindowsId($TimezoneId.Trim(), [ref]$winId)) {
            throw "Cannot resolve timezone: $TimezoneId"
        }
        $tzInfo = [TimeZoneInfo]::FindSystemTimeZoneById($winId)
    }
    return [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tzInfo)
}

function Test-CtgIsLocalSixAmWindow {
    param(
        [string] $TimezoneId,
        [int] $WindowMinutes = 5
    )
    $local = Get-CtgLocalTimeInTimezone -TimezoneId $TimezoneId
    if ($local.Hour -ne 6) { return $false }
    return ($local.Minute -lt $WindowMinutes)
}

function Get-CtgDailyUtmsAlertSentToday {
    param([string] $TimezoneId)
    $stateFile = Get-CtgDailyUtmsAlertStateFile
    if (-not (Test-Path $stateFile)) { return $false }
    try {
        $state = Get-Content -Path $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
        $local = Get-CtgLocalTimeInTimezone -TimezoneId $TimezoneId
        $today = $local.ToString('yyyy-MM-dd')
        return ([string]$state.last_sent_date -eq $today -and [string]$state.timezone -eq $TimezoneId)
    } catch {
        return $false
    }
}

function Set-CtgDailyUtmsAlertSentToday {
    param([string] $TimezoneId)
    $dir = Get-CtgIphoneTimezoneDir
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $local = Get-CtgLocalTimeInTimezone -TimezoneId $TimezoneId
    $state = [ordered]@{
        timezone       = $TimezoneId
        last_sent_date = $local.ToString('yyyy-MM-dd')
        last_sent_at   = (Get-Date).ToString('o')
    }
    $state | ConvertTo-Json | Set-Content -Path (Get-CtgDailyUtmsAlertStateFile) -Encoding utf8
}

function Get-CtgDefaultUtmsAlertTimezone {
    return 'America/New_York'
}
