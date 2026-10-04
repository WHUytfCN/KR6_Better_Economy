[CmdletBinding()]
param([string]$OutputDirectory,[string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo 'dist' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $repo 'build' }
$build = [IO.Path]::GetFullPath($BuildDirectory)
New-Item -ItemType Directory -Path $build,$output -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework C# compiler not found.' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$files = @('entry.lua','Start-Economy.cmd','Start-Economy.ps1','supported-build.json','settings.ini','README.md','LICENSE.md','NOTICE.md',
    'src/bootstrap.lua','src/core.lua','src/config.lua','src/runtime.lua','src/ui.lua')
$hashes = [ordered]@{}
function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Write-Zip([string]$Path,[string]$Prefix) {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Create)
    $zip = New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
        foreach ($name in $files) {
            $bytes = [IO.File]::ReadAllBytes((Join-Path $repo $name))
            $hashes[$name] = Get-BytesHash $bytes
            $entry = $zip.CreateEntry($Prefix + $name,[IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
            $target = $entry.Open()
            try { $target.Write($bytes,0,$bytes.Length) } finally { $target.Dispose() }
        }
    } finally { $zip.Dispose(); $stream.Dispose() }
}
foreach ($name in $files) { if (-not (Test-Path -LiteralPath (Join-Path $repo $name) -PathType Leaf)) { throw "Missing release file: $name" } }
$utf8 = New-Object Text.UTF8Encoding($false)
$payload = Join-Path $build 'payload.zip'
Write-Zip $payload ''
$manifest = Join-Path $build 'payload-manifest.json'
[IO.File]::WriteAllText($manifest,($hashes | ConvertTo-Json),$utf8)
$portable = Join-Path $output 'KR6_Better_Economy-v0.1.0-portable.zip'
Write-Zip $portable 'KR6_Better_Economy/'
$setup = Join-Path $output 'KR6_Better_Economy-v0.1.0-Setup.exe'
$arguments = @('/nologo','/codepage:65001','/target:winexe','/platform:anycpu','/optimize+',
    '/r:System.IO.Compression.dll','/r:System.Web.Extensions.dll','/r:System.Windows.Forms.dll','/r:System.Drawing.dll',
    "/win32manifest:$(Join-Path $repo 'installer\app.manifest')", "/out:$setup",
    "/resource:$payload,payload.zip", "/resource:$manifest,payload-manifest.json")
$sources = @('installer\InstallCore.cs','installer\SteamLocator.cs','installer\Program.cs') | ForEach-Object { Join-Path $repo $_ }
& $compiler @arguments @sources
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$p = Start-Process -FilePath $setup -ArgumentList '--verify-package' -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0) { throw 'Embedded payload verification failed.' }
$lines = foreach ($path in @($setup,$portable)) {
    (Get-BytesHash ([IO.File]::ReadAllBytes($path))) + '  ' + [IO.Path]::GetFileName($path)
}
[IO.File]::WriteAllLines((Join-Path $output 'SHA256SUMS.txt'),[string[]]$lines,$utf8)
Write-Host "Build and embedded-package verification passed: $output"
