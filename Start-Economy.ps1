[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
try {
    $pluginRoot = $PSScriptRoot
    if ([System.IO.Path]::GetFileName($pluginRoot) -cne 'KR6_Better_Economy') {
        throw 'Keep the complete plugin folder named KR6_Better_Economy.'
    }
    # Support both the installed folder and a source checkout below the game directory.
    $ancestor = [System.IO.Directory]::GetParent($pluginRoot)
    while ($null -ne $ancestor -and -not (Test-Path -LiteralPath (Join-Path $ancestor.FullName 'Kingdom Rush Genesis.exe') -PathType Leaf)) {
        $ancestor = $ancestor.Parent
    }
    if ($null -eq $ancestor) { throw 'Game not found above this folder. Install with Setup.exe or place KR6_Better_Economy inside the game directory.' }
    $gameRoot = $ancestor.FullName
    $gameExe = Join-Path $gameRoot 'Kingdom Rush Genesis.exe'
    $relativeRoot = $pluginRoot.Substring($gameRoot.Length).TrimStart([char]'\',[char]'/') -replace '\\','/'
    # Lua require translates dots in module names to separators. Our supported layouts
    # use these portable path segments; reject ambiguous names before starting the game.
    if ($relativeRoot -notmatch '^[A-Za-z0-9_/-]+$') { throw 'Plugin subfolder names may only contain letters, numbers, underscores and hyphens. Use Setup.exe for the standard layout.' }
    foreach ($pluginFile in @('entry.lua','src/bootstrap.lua','src/core.lua','src/config.lua','src/runtime.lua','src/ui.lua')) {
        if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot $pluginFile) -PathType Leaf)) {
            throw "Missing plugin file: $pluginFile"
        }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $pluginRoot 'supported-build.json') -Raw | ConvertFrom-Json
    foreach ($entry in $manifest.files.PSObject.Properties) {
        $target = Join-Path $gameRoot $entry.Name
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing game file: $($entry.Name)" }
        $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
        $hashStream = [System.IO.File]::OpenRead($target)
        try { $actual = [BitConverter]::ToString($hashAlgorithm.ComputeHash($hashStream)).Replace('-','') }
        finally { $hashStream.Dispose(); $hashAlgorithm.Dispose() }
        if ($actual -ne $entry.Value) { throw "Unsupported or changed game build: $($entry.Name). Plugin not started." }
    }
    # Parse values as data only. Never execute settings content.
    $settings = @{}
    foreach ($line in (Get-Content -LiteralPath (Join-Path $pluginRoot 'settings.ini'))) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([a-z]+)\s*=\s*(.*?)\s*$') { throw 'Malformed plugin settings.' }
        $key = $Matches[1]; $value = $Matches[2]
        if ($settings.ContainsKey($key)) { throw "Duplicate setting: $key" }
        if ($key -in @('enabled','summons')) {
            if ($value -cnotin @('true','false')) { throw "Invalid switch: $key" }
        } elseif ($key -in @('global','initial','enemy')) {
            $number = 0.0
            if (-not [double]::TryParse($value,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)) { throw "Invalid multiplier: $key" }
            if ([double]::IsNaN($number) -or $number -lt 0.75 -or $number -gt 1.25 -or [Math]::Abs($number*20-[Math]::Round($number*20)) -gt 1e-8) { throw "Multiplier out of presets: $key" }
        } else { throw "Unknown setting: $key" }
        $settings[$key]=$value
    }
    # The real game's startup path did not retain LUA_PATH. Use its default disk loader.
    $gameArguments = '-custom_script ' + $relativeRoot + '/entry'
    if ($CheckOnly) {
        [pscustomobject]@{Status='CHECK PASSED - game was not started';Version=$manifest.version;
            Executable=$gameExe;Arguments=$gameArguments;WorkingDirectory=$gameRoot} | Format-List
        exit 0
    }
    if (Get-Process -Name 'Kingdom Rush Genesis' -ErrorAction SilentlyContinue) {
        throw 'Close the game first, then start this launcher. Attaching to a running game is not supported.'
    }
    New-Item -ItemType Directory -Path (Join-Path $pluginRoot 'logs') -Force | Out-Null
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName=$gameExe
    $start.Arguments=$gameArguments
    $start.WorkingDirectory=$gameRoot
    $start.UseShellExecute=$false
    Write-Host 'Starting KR6 with the economy plugin. Normal Steam launch remains unchanged.'
    $process=[System.Diagnostics.Process]::Start($start)
    Write-Host "Game process started: $($process.Id). Open the last settings page for economy controls."
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
