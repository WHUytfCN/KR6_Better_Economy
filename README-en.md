# KR6 Better Economy

[简体中文](README.md) | [English](README-en.md)

Optional economy adjustments for **Kingdom Rush 6: Genesis**, giving players more room to experiment with tower and hero combinations while keeping the original challenge available.

**A free, unofficial plugin. Please support the official game.** This plugin does not include the game or unlock paid content.

## Download and install

Download from this repository's [Releases page](https://github.com/WHUytfCN/KR6_Better_Economy/releases):

- **Setup.exe**: automatically finds the Steam game directory. You can also click **浏览…** (Browse) to select it manually, then confirm the installation.
- **portable.zip**: extract the `KR6_Better_Economy` folder into the game directory, alongside `Kingdom Rush Genesis.exe`.

Close the game before installing. The installer includes all plugin files and does not need to download anything else.
The installation folder must be named **KR6_Better_Economy**; do not rename it.
GitHub's automatically generated **Source code** archives contain the source code. Players should use the installer or portable package listed above.

## Launch and settings

1. Open the `KR6_Better_Economy` folder inside your game directory.
2. Double-click **Start-Economy.cmd** to launch the game with the plugin.
3. Open the game's gear/settings menu and go to the last page, titled **金币控制** (Gold controls).

You must run this launcher manually each time you want to use the plugin. Launching the game normally through Steam keeps the original gameplay.

The plugin's settings page currently uses Chinese labels. The table below explains them in English; English documentation does not change the in-game interface language.

| In-game label | English meaning | Effect |
|---|---|---|
| 全局金币倍率 | Global gold multiplier | Adjusts gold income during a level, excluding tower sale refunds |
| 开局金币倍率 | Starting gold multiplier | Original starting gold × global multiplier × starting multiplier |
| 敌人赏金倍率 | Enemy bounty multiplier | Original enemy bounty × global multiplier × enemy multiplier |
| 召唤物掉落金币 | Gold from enemy summons | Restores the corresponding regular unit's base bounty for verified enemy summons |

All three multipliers range from **×0.75 to ×1.25** in steps of 0.05 and default to ×1.00. Bounties for enemy summons are off by default.
Tower purchase costs, upgrade costs, and tower sale refunds retain their original rules. Settings affect future income only; the starting gold multiplier takes effect the next time you start a level.

Enemy reinforcements and split-off units are treated separately from phase changes. A gargoyle falling to the ground and reviving is not considered a summon.
With summon bounties off, the original gold-drop rules apply. Special units without a valid base bounty remain unchanged.

Other buttons on the settings page:

| In-game label | English meaning |
|---|---|
| 开启 / 关（原版） | On / Off (original rules) |
| 金币插件：启用 / 金币插件：停用 | Economy plugin: enabled / disabled |
| 恢复默认 | Restore defaults |
| 已保存到插件目录 | Saved to the plugin folder |

## Compatibility and updates

- Supports **Windows 10/11 and Steam Windows build kr6-desktop-1.00.072**.
- Installation or launch is refused if the game files do not match the supported build. After a game update, wait for a compatible plugin release.
- The installer requires .NET Framework 4.5 or later. Running the plugin requires Windows PowerShell.
- The installer does not currently support symbolic links or directory junctions. You need write access to the installation directory.
- The installer is not code-signed, so Windows may show an unknown publisher warning. Check the download source and the included `SHA256SUMS.txt`.
- Running the installer again preserves your existing settings. When upgrading from the old `KR6Economy` folder, it copies the old settings only if the new folder has no configuration, and leaves the old folder in place.
- Before updating by manually extracting a portable package, back up `settings.ini` so that the package's defaults do not overwrite your settings.

## Disable or uninstall

You can disable economy adjustments on the settings page. To play the original game, close it and launch it normally through Steam.
To uninstall, close the game and delete the `KR6_Better_Economy` folder. Back up `settings.ini` first if you want to keep your settings.

## Report an issue

This is a public test release. Some floating text for rewards other than kills may still display the original amount; use the change in your gold balance to check the actual reward.
Please report problems through [Issues](https://github.com/WHUytfCN/KR6_Better_Economy/issues), including your game version, level and mode, multiplier settings, summon toggle, steps to reproduce, and expected versus actual results.
The log is located at `KR6_Better_Economy/logs/plugin.log`. You may redact personal paths before uploading it.

## License and notices

Author: **WHUytfCN**. The source is available for noncommercial use under [PolyForm Noncommercial 1.0.0](LICENSE.md).
Please retain the [attribution and rights notices](NOTICE.md). This project is not affiliated with or endorsed by Ironhide. The game and related rights belong to their respective owners.

## More documentation

- [Release notes](docs-en/RELEASE_NOTES.md)
- [Building and testing (for maintainers)](docs-en/BUILD.md)
