# Building and testing

[简体中文](../docs/BUILD.md) | [English](BUILD.md) | [Back to README](../README-en.md)

You do not need development tools to use the plugin. This page is for maintainers building the installer from source.

## Build the installer

On Windows 10/11, open PowerShell in the repository root and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

The script uses the .NET Framework C# compiler included with Windows and does not download tools.
It writes the installer, portable ZIP, and `SHA256SUMS.txt` to `dist/`, with intermediate resources in `build/`.
Use `-OutputDirectory` to choose a different output directory. The version is currently explicitly set to `0.1.0` in the build script, assembly metadata, and documentation. Update these together and rebuild when releasing a new version.
The installer is unsigned, and recompiling the EXE is not guaranteed to produce byte-for-byte identical output.

Packaging uses an explicit file list containing `src`, the entry point, launchers, default configuration, supported-build hashes, README, and license notices.
It does not read the game's archives or include local logs or game files in the package. `SHA256SUMS.txt` checks file transfer integrity; it is not a substitute for code signing or a trusted download source.

## Test the installer

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-installer.ps1
```

The tests create fake game files under `build/test-<random-id>/` to check discovery, validation, configuration preservation, and rollback.
They do not install into the real game directory or launch the game. Fixtures are kept for inspection; you can delete `build/` after testing.
The installer also supports a read-only check of its embedded package: `Setup.exe --verify-package` (exit code 0 means success). Replace `Setup.exe` with the actual installer filename.

## Test Lua

Install Python with the same architecture as the target DLL, and point the tests to the LuaJIT DLL from your own legitimate game installation. Replace the example path below with your game directory:

```powershell
python .\scripts\test-lua.py --lua-dll 'C:\Path\To\Your\Game\lua51.dll'
python .\scripts\test-launcher.py --lua-dll 'C:\Path\To\Your\Game\lua51.dll'
```

The public repository contains project-authored tests and mock dependencies, not extracted game bytecode.
Launcher tests cover both the standard installation folder and a source folder nested inside the game directory. Both entry points are loaded directly through LuaJIT for verification.
If your source checkout is outside the game directory, install the runtime files into the game directory first, then use the installed launcher.
GUI snapshots and native Lua calls do not replace testing in the actual game or on other computers.

## Implementation boundaries

Steam discovery uses the registry's `SteamPath`/`InstallPath`, `libraryfolders.vdf`, and `appmanifest_4259190.acf`.
Installation validates the supported game hashes and extracts the hash-verified embedded ZIP into `KR6_Better_Economy`, preserving an existing `settings.ini`.
Files are staged before replacement. If installation fails, files overwritten by that attempt are restored. If rollback itself fails, the backup directory is retained and its location is reported.
Automatic rollback is not guaranteed after a power outage or forced process termination. If either occurs, keep the `.install-*` directory and inspect the installation before proceeding.
The installer rejects paths escaping the target directory, duplicate ZIP entries, symbolic links, and directory junctions. It does not modify the game's EXE/DLL files, saves, or Steam launch settings.
