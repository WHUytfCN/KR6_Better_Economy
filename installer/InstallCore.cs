using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Web.Script.Serialization;

namespace KR6BetterEconomy {
    internal sealed class BuildInfo { public string version {get;set;} public Dictionary<string,string> files {get;set;} }
    internal sealed class Payload {
        internal Dictionary<string,byte[]> Files;
        internal BuildInfo Build;
        internal static Payload Read(Stream zip,Stream manifest) {
            var serializer=new JavaScriptSerializer();
            Dictionary<string,string> hashes;
            using(var reader=new StreamReader(manifest,Encoding.UTF8)) hashes=serializer.Deserialize<Dictionary<string,string>>(reader.ReadToEnd());
            if(hashes==null || hashes.Count<11 || hashes.Count>40) throw new InvalidDataException("安装包清单不完整。");
            var files=new Dictionary<string,byte[]>(StringComparer.OrdinalIgnoreCase);
            using(var archive=new ZipArchive(zip,ZipArchiveMode.Read,true)) {
                foreach(var e in archive.Entries) {
                    string name=e.FullName;
                    InstallCore.SafePath(Path.GetTempPath(),name);
                    if(e.Length>4*1024*1024 || files.ContainsKey(name) || !hashes.ContainsKey(name)) throw new InvalidDataException("安装包包含异常文件。");
                    byte[] bytes;
                    using(var input=e.Open()) using(var output=new MemoryStream()) {input.CopyTo(output);bytes=output.ToArray();}
                    if(InstallCore.Hash(bytes)!=hashes[name]) throw new InvalidDataException("安装包校验失败："+name);
                    files.Add(name,bytes);
                }
            }
            if(files.Count!=hashes.Count) throw new InvalidDataException("安装包缺少文件。");
            foreach(string name in new[]{"entry.lua","Start-Economy.cmd","Start-Economy.ps1","supported-build.json","settings.ini","src/core.lua","src/config.lua","src/runtime.lua","src/ui.lua","src/bootstrap.lua","README.md"})
                if(!files.ContainsKey(name)) throw new InvalidDataException("安装包缺少："+name);
            var build=serializer.Deserialize<BuildInfo>(Encoding.UTF8.GetString(files["supported-build.json"]).TrimStart('\uFEFF'));
            if(build==null || build.files==null || build.files.Count!=3) throw new InvalidDataException("游戏版本清单无效。");
            foreach(string name in new[]{"Kingdom Rush Genesis.exe","love.dll","lua51.dll"}) {
                string hash; if(!build.files.TryGetValue(name,out hash) || hash==null || hash.Length!=64 || !hash.All(Uri.IsHexDigit)) throw new InvalidDataException("游戏校验值无效。");
            }
            return new Payload {Files=files,Build=build};
        }
    }
    internal static class InstallCore {
        internal static string Hash(byte[] bytes) {using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
        static string FileHash(string path) {using(var stream=File.OpenRead(path)) using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant();}
        internal static string SafePath(string root,string name) {
            if(String.IsNullOrEmpty(name) || name.Contains("\\") || name.Contains(":") || Path.IsPathRooted(name)) throw new InvalidDataException("非法安装路径。");
            foreach(string part in name.Split('/'))
                if(part=="" || part=="." || part==".." || part.EndsWith(".") || part.EndsWith(" ") || part.IndexOfAny(Path.GetInvalidFileNameChars())>=0) throw new InvalidDataException("非法安装路径。");
            string prefix=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
            string path=Path.GetFullPath(Path.Combine(prefix,name.Replace('/',Path.DirectorySeparatorChar)));
            if(!path.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("安装路径越界。");
            return path;
        }
        internal static void NoLinks(string path) {
            string p=Path.GetFullPath(path);
            while(!String.IsNullOrEmpty(p)) {
                if((File.Exists(p) || Directory.Exists(p)) && (File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0) throw new IOException("不支持链接或联接目录："+p);
                p=Path.GetDirectoryName(p);
            }
        }
        internal static void CheckGame(string game,BuildInfo build) {
            NoLinks(game);
            foreach(var entry in build.files) {
                string path=SafePath(game,entry.Key);NoLinks(path);
                if(!File.Exists(path)) throw new IOException("请选择包含 Kingdom Rush Genesis.exe 的游戏目录。");
                if(!String.Equals(FileHash(path),entry.Value,StringComparison.OrdinalIgnoreCase)) throw new IOException("当前游戏构建不受支持："+entry.Key+"。本版适配 "+build.version+"。");
            }
        }
        sealed class Change {internal string Target,Backup;internal bool Written;}
        internal static void Install(string game,Payload payload,Func<bool> running,Action<string> beforeWrite) {
            game=Path.GetFullPath(game);
            if(running()) throw new IOException("请先关闭 Kingdom Rush Genesis，再安装插件。");
            CheckGame(game,payload.Build);
            string plugin=Path.Combine(game,"KR6_Better_Economy");NoLinks(plugin);
            foreach(string name in payload.Files.Keys) NoLinks(SafePath(plugin,name));
            if(running()) throw new IOException("游戏正在运行，请先关闭游戏。");
            Directory.CreateDirectory(plugin);
            string stage=Path.Combine(plugin,".install-"+Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(stage);
            var changes=new List<Change>();bool keepBackup=false;
            try {
                // Stage all files before touching the working installation.
                foreach(var file in payload.Files) {
                    string target=SafePath(stage,"new/"+file.Key);Directory.CreateDirectory(Path.GetDirectoryName(target));
                    byte[] content=file.Value;
                    if(file.Key=="settings.ini" && !File.Exists(Path.Combine(plugin,"settings.ini"))) {
                        string legacy=Path.Combine(game,"KR6Economy/settings.ini");
                        if(File.Exists(legacy)) {
                            NoLinks(legacy);
                            if(new FileInfo(legacy).Length>65536) throw new IOException("旧版配置文件过大，请检查 KR6Economy/settings.ini。");
                            content=File.ReadAllBytes(legacy);
                        }
                    }
                    File.WriteAllBytes(target,content);
                    if(FileHash(target)!=Hash(content)) throw new IOException("写入校验失败。");
                }
                foreach(var file in payload.Files.OrderBy(f=>f.Key,StringComparer.Ordinal)) {
                    string target=SafePath(plugin,file.Key);NoLinks(target);
                    if(file.Key=="settings.ini" && File.Exists(target)) continue;
                    if(beforeWrite!=null) beforeWrite(target);
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    var change=new Change {Target=target};changes.Add(change);
                    if(File.Exists(target)) {
                        string backup=SafePath(stage,"old/"+file.Key);Directory.CreateDirectory(Path.GetDirectoryName(backup));
                        File.Move(target,backup);change.Backup=backup;
                    }
                    File.Move(SafePath(stage,"new/"+file.Key),target);change.Written=true;
                }
            } catch(Exception original) {
                var errors=new List<Exception>();
                for(int i=changes.Count-1;i>=0;i--) {
                    var c=changes[i];
                    try {NoLinks(c.Target);if(c.Written) File.Delete(c.Target);if(c.Backup!=null) File.Move(c.Backup,c.Target);}
                    catch(Exception e) {errors.Add(e);}
                }
                if(errors.Count>0) {keepBackup=true;throw new IOException("安装失败，部分文件无法回滚。请保留备份目录："+stage,original);}
                throw;
            } finally {
                if(!keepBackup) {try {NoLinks(stage);Directory.Delete(stage,true);} catch(IOException) {} catch(UnauthorizedAccessException) {}}
            }
        }
    }
}
