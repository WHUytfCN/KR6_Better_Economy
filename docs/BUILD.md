# 构建与测试

[简体中文](BUILD.md) | [English](../docs-en/BUILD.md) | [返回 README](../README.md)

运行插件不需要开发工具。本页仅用于维护者从源码构建安装器。

## 构建安装器

在 Windows 10/11 上，从仓库根目录打开 PowerShell：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

脚本使用 Windows 自带 .NET Framework C# 编译器，不下载工具。
`dist/` 输出安装器、便携 ZIP 和 SHA256SUMS.txt；`build/` 保存中间资源。
也可传 `-OutputDirectory` 指定发布产物目录。版本号目前在构建脚本、程序集及说明中明确写为 0.1.0，
发新版时须同步更新并重新构建。安装器未签名，重新编译的 EXE 不承诺逐字节相同。

打包采用显式文件列表，包含 src、入口、启动器、默认配置、版本哈希、README 和许可说明。
不读取游戏档案，不把本机日志或游戏文件收入包。SHA256SUMS.txt 用于检查传输完整性，
不能替代代码签名或可信下载来源。

## 测试安装器

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-installer.ps1
```

在 `build/test-随机标识/` 内构造假游戏文件，测试查找、校验、配置保留和回滚。
不会安装到真实游戏目录，不启动游戏。夹具保留供检查，可在测试后自行删除 `build/`。
安装器也支持只读资源自检：`Setup.exe --verify-package`（退出码 0 表示通过）。

## 测试 Lua

安装 Python（与目标 DLL 位数一致），指定自己合法安装的游戏 LuaJIT DLL：

```powershell
python .\scripts\test-lua.py --lua-dll '你的游戏目录\lua51.dll'
python .\scripts\test-launcher.py --lua-dll '你的游戏目录\lua51.dll'
```

公开仓库只包含编写的测试和模拟依赖，不包含提取的游戏字节码。
启动器测试覆盖标准安装目录与游戏目录下的嵌套源码目录；两种入口均直接通过 LuaJIT 加载验证。
源码若位于游戏目录之外，请先将运行文件安装到游戏目录，再使用安装后的启动器。
GUI 快照或原生 Lua 调用无法替代真实游戏和其他电脑上的验收。

## 实现边界

Steam 查找：注册表 SteamPath/InstallPath、libraryfolders.vdf、appmanifest_4259190.acf。
安装：验证支持的游戏哈希，将经过哈希校验的内置 ZIP 写入 KR6_Better_Economy；保留已有 settings.ini。
写入前暂存，失败时还原本次覆盖文件；若回滚本身失败，保留备份目录并告知路径。
断电/强制结束进程不属于自动回滚保证，遇到此情况保留 `.install-*` 目录后重新检查安装。
拒绝路径越界、压缩包重复项及符号链接/目录联接；不会写游戏 EXE/DLL、存档或 Steam 启动设置。
