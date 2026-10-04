[CmdletBinding()]
param([string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $repo 'build' }
$build = [IO.Path]::GetFullPath($BuildDirectory)
New-Item -ItemType Directory -Path $build -Force | Out-Null
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $build 'installer-tests.exe'
$files = @('installer\InstallCore.cs','installer\SteamLocator.cs','tests\InstallerTests.cs') | ForEach-Object { Join-Path $repo $_ }
& $compiler /nologo /codepage:65001 /target:exe "/out:$exe" /r:System.IO.Compression.dll /r:System.Web.Extensions.dll @files
if ($LASTEXITCODE -ne 0) { throw 'Installer test compilation failed.' }
$fixture = Join-Path $build ('test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture,(Join-Path $fixture 'link-target') -Force | Out-Null
$junction = Join-Path $fixture 'junction'
New-Item -ItemType Junction -Path $junction -Target (Join-Path $fixture 'link-target') | Out-Null
& $exe $fixture $junction
if ($LASTEXITCODE -ne 0) { throw "Installer tests failed. Fixture retained at $fixture" }
Write-Host "Fixture retained for inspection: $fixture"
