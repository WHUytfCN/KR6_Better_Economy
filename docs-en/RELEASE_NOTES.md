# KR6 Better Economy v0.1.0 — First public test release

[简体中文](../docs/RELEASE_NOTES.md) | [English](RELEASE_NOTES.md) | [Back to README](../README-en.md)

Optional economy adjustments for individual levels, with global, starting gold, and enemy bounty multipliers, plus a toggle for bounties from enemy summons.
Original combat, tower purchase and upgrade costs, and tower sale refund rules are preserved. All three multipliers default to ×1.00, with summon bounties off.

## Downloads

- `KR6_Better_Economy-v0.1.0-Setup.exe`: recommended for players. Automatically finds the Steam game directory and installs the plugin; manual selection is also supported.
- `KR6_Better_Economy-v0.1.0-portable.zip`: extract into the game directory, keeping the top-level `KR6_Better_Economy` folder.
- `SHA256SUMS.txt`: SHA-256 checksums for the two files above.

The installer includes the plugin and does not need an additional download. **The game is not included. Please support the official game.**
After installation, you must still manually run `KR6_Better_Economy/Start-Economy.cmd` to use the plugin. Normal Steam launches keep the original gameplay.
The installation folder is now consistently named `KR6_Better_Economy`. Updates preserve settings in this folder first; if none exist, the installer imports settings from the old `KR6Economy` folder.

## Compatibility and limitations

- Windows 10/11, Steam build `kr6-desktop-1.00.072`. Game file hashes must match.
- Game updates may require a new compatible plugin release. This version does not bypass validation.
- Five groups of core gameplay checks and font rendering have been tested locally. Testing across other computers remains limited.
- Some floating text for rewards other than kills may still display the original amount; use the change in your gold balance to check the actual reward.
- The first installer release is unsigned. Download it from this repository and check the file hashes. Do not disable security protection.

For English explanations of the current Chinese settings labels, see the [settings guide](../README-en.md#launch-and-settings).

Source available for noncommercial use under [PolyForm Noncommercial 1.0.0](../LICENSE.md). Author: WHUytfCN.
An unofficial project, not affiliated with or endorsed by Ironhide.
