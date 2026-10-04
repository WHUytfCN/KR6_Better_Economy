using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;
using System.Web.Script.Serialization;
using KR6BetterEconomy;

class InstallerTests {
    static int count;
    static void Check(bool condition, string name) { if (!condition) throw new Exception(name); count++; Console.WriteLine("PASS " + name); }
    static void Reject(Action action, string name) { bool rejected=false; try { action(); } catch { rejected=true; } Check(rejected,name); }
    static string root;
    static string Dir(string name) { string p=Path.Combine(root,name); Directory.CreateDirectory(p); return p; }
    static MemoryStream Zip(Dictionary<string,byte[]> files) {
        var stream=new MemoryStream();
        using(var archive=new ZipArchive(stream,ZipArchiveMode.Create,true))
            foreach(var pair in files) using(var output=archive.CreateEntry(pair.Key).Open()) output.Write(pair.Value,0,pair.Value.Length);
        stream.Position=0;return stream;
    }
    static Payload Read(Dictionary<string,byte[]> files, Dictionary<string,string> hashes) {
        using(var zip=Zip(files)) using(var manifest=new MemoryStream(Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(hashes)))) return Payload.Read(zip,manifest);
    }
    static string Game(string name, Payload payload) {
        string p=Dir(name); foreach(var f in payload.Build.files) File.WriteAllText(Path.Combine(p,f.Key),f.Key); return p;
    }
    static Payload Fixture() {
        var files=new Dictionary<string,byte[]>();
        foreach(string name in new[]{"entry.lua","Start-Economy.cmd","Start-Economy.ps1","settings.ini","README.md","src/core.lua","src/config.lua","src/runtime.lua","src/ui.lua","src/bootstrap.lua"}) files[name]=Encoding.UTF8.GetBytes("new "+name);
        var build=new BuildInfo {version="fixture",files=new Dictionary<string,string>()};
        foreach(string name in new[]{"Kingdom Rush Genesis.exe","love.dll","lua51.dll"}) build.files[name]=InstallCore.Hash(Encoding.UTF8.GetBytes(name));
        files["supported-build.json"]=Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(build));
        var hashes=new Dictionary<string,string>(); foreach(var f in files) hashes[f.Key]=InstallCore.Hash(f.Value);
        return Read(files,hashes);
    }
    static int Main(string[] args) {try {Run(args);return 0;} catch(Exception e) {Console.WriteLine("FAIL "+e.GetType().Name+": "+e.Message);return 1;}}
    static void Run(string[] args) {
        root=Path.GetFullPath(args[0]); Directory.CreateDirectory(root);
        var vdf=Vdf.Parse("// comment\n\"libraryfolders\" { \"0\" {\"path\" \"D:\\\\Steam Lib\" \"apps\" {\"4259190\" \"1\"}} \"1\" \"E:\\\\Old Library\" }");
        Check(vdf.Child("libraryfolders").Child("0").Value("path")==@"D:\Steam Lib","modern VDF escaped path");
        Check(vdf.Child("libraryfolders").Value("1")==@"E:\Old Library","legacy VDF path");
        Reject(()=>Vdf.Parse("\"x\" {"),"malformed VDF rejected");
        string steam=Dir("Steam with spaces"), library=Dir("中文 library");
        Directory.CreateDirectory(Path.Combine(steam,"steamapps"));
        File.WriteAllText(Path.Combine(steam,"steamapps/libraryfolders.vdf"),"\"libraryfolders\" {\"0\" {\"path\" \""+library.Replace("\\","\\\\")+"\"}}");
        Directory.CreateDirectory(Path.Combine(library,"steamapps/common/Custom game"));
        File.WriteAllText(Path.Combine(library,"steamapps/appmanifest_4259190.acf"),"\"AppState\" {\"appid\" \"4259190\" \"installdir\" \"Custom game\"}");
        File.WriteAllText(Path.Combine(library,"steamapps/common/Custom game/Kingdom Rush Genesis.exe"),"fixture");
        Check(SteamLocator.Find(new[]{steam}).ConvertAll(Path.GetFullPath).Contains(Path.GetFullPath(Path.Combine(library,"steamapps/common/Custom game"))),"secondary Steam library and manifest detected");
        var payload=Fixture(); Check(payload.Files.Count==11,"embedded payload verified");
        var bad=new Dictionary<string,byte[]>(payload.Files);bad["../escape.lua"]=new byte[]{1};
        var hashes=new Dictionary<string,string>();foreach(var f in bad)hashes[f.Key]=InstallCore.Hash(f.Value);
        Reject(()=>Read(bad,hashes),"ZIP traversal rejected");
        bad=new Dictionary<string,byte[]>(payload.Files);hashes.Clear();foreach(var f in bad)hashes[f.Key]=InstallCore.Hash(f.Value);
        hashes["entry.lua"]=new string('0',64);
        Reject(()=>Read(bad,hashes),"payload hash mismatch rejected");
        hashes.Clear();foreach(var f in bad)hashes[f.Key]=InstallCore.Hash(f.Value);
        bad.Remove("src/ui.lua");Reject(()=>Read(bad,hashes),"missing payload entry rejected");
        Reject(()=>InstallCore.SafePath(root,"C:/evil"),"rooted payload path rejected");
        Reject(()=>InstallCore.SafePath(root,"file:stream"),"alternate data stream rejected");
        string game=Game("fresh game",payload);
        InstallCore.Install(game,payload,()=>false,null);
        Check(File.ReadAllText(Path.Combine(game,"KR6_Better_Economy/src/core.lua"))=="new src/core.lua","fresh install");
        Check(File.ReadAllText(Path.Combine(game,"Kingdom Rush Genesis.exe"))=="Kingdom Rush Genesis.exe","game original preserved");
        File.WriteAllText(Path.Combine(game,"KR6_Better_Economy/settings.ini"),"global=1.2");
        File.WriteAllText(Path.Combine(game,"KR6_Better_Economy/entry.lua"),"old entry");
        InstallCore.Install(game,payload,()=>false,null);
        Check(File.ReadAllText(Path.Combine(game,"KR6_Better_Economy/settings.ini"))=="global=1.2","existing config preserved");
        Check(File.ReadAllText(Path.Combine(game,"KR6_Better_Economy/entry.lua"))=="new entry.lua","upgrade replaces plugin code");
        string rollback=Game("rollback",payload); Directory.CreateDirectory(Path.Combine(rollback,"KR6_Better_Economy"));
        File.WriteAllText(Path.Combine(rollback,"KR6_Better_Economy/entry.lua"),"old entry");
        File.WriteAllText(Path.Combine(rollback,"KR6_Better_Economy/README.md"),"old readme");
        int writes=0;
        Reject(()=>InstallCore.Install(rollback,payload,()=>false, path=>{if(++writes==3) throw new IOException("injected failure");}),"mid-install failure reported");
        Check(File.ReadAllText(Path.Combine(rollback,"KR6_Better_Economy/entry.lua"))=="old entry","rollback restores previous code");
        Check(File.ReadAllText(Path.Combine(rollback,"KR6_Better_Economy/README.md"))=="old readme","rollback restores a file already overwritten");
        Check(!File.Exists(Path.Combine(rollback,"KR6_Better_Economy/Start-Economy.cmd")),"rollback removes newly installed files");
        string wrong=Game("wrong build",payload); File.AppendAllText(Path.Combine(wrong,"love.dll"),"changed");
        Reject(()=>InstallCore.Install(wrong,payload,()=>false,null),"unsupported game refused");
        Check(!Directory.Exists(Path.Combine(wrong,"KR6_Better_Economy")),"unsupported game leaves no plugin directory");
        string running=Game("running",payload);
        Reject(()=>InstallCore.Install(running,payload,()=>true,null),"running game refused");
        Check(!Directory.Exists(Path.Combine(running,"KR6_Better_Economy")),"running game untouched");
        string legacy=Game("legacy upgrade",payload);Directory.CreateDirectory(Path.Combine(legacy,"KR6Economy"));
        File.WriteAllText(Path.Combine(legacy,"KR6Economy/settings.ini"),"global=1.2");
        File.WriteAllText(Path.Combine(legacy,"KR6Economy/user-file.txt"),"keep this");
        InstallCore.Install(legacy,payload,()=>false,null);
        Check(File.ReadAllText(Path.Combine(legacy,"KR6_Better_Economy/settings.ini"))=="global=1.2","legacy configuration imported");
        Check(File.ReadAllText(Path.Combine(legacy,"KR6Economy/user-file.txt"))=="keep this","legacy directory left intact");
        File.WriteAllText(Path.Combine(legacy,"KR6_Better_Economy/settings.ini"),"global=0.9");
        InstallCore.Install(legacy,payload,()=>false,null);
        Check(File.ReadAllText(Path.Combine(legacy,"KR6_Better_Economy/settings.ini"))=="global=0.9","current configuration wins over legacy");
        if(args.Length>1) Reject(()=>InstallCore.NoLinks(Path.Combine(args[1],"file.lua")),"directory junction rejected");
        Console.WriteLine(count+" installer checks passed");
    }
}
