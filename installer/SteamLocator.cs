using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using Microsoft.Win32;

namespace KR6BetterEconomy {
    internal sealed class Vdf {
        readonly Dictionary<string,string> values=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        readonly Dictionary<string,Vdf> children=new Dictionary<string,Vdf>(StringComparer.OrdinalIgnoreCase);
        internal string Value(string key) { string v; return values.TryGetValue(key,out v)?v:null; }
        internal Vdf Child(string key) { Vdf v; return children.TryGetValue(key,out v)?v:new Vdf(); }
        internal IEnumerable<string> Paths() {
            foreach(var c in children.Values) { var p=c.Value("path"); if(p!=null) yield return p; }
            foreach(var v in values) { int i; if(Int32.TryParse(v.Key,out i)) yield return v.Value; }
        }
        static string Token(string text,ref int p) {
            while(p<text.Length) {
                if(Char.IsWhiteSpace(text[p]) || text[p]=='\uFEFF') {p++;continue;}
                if(text[p]=='/' && p+1<text.Length && text[p+1]=='/') {while(p<text.Length && text[p]!='\n') p++;continue;}
                break;
            }
            if(p==text.Length) return null;
            char c=text[p++]; if(c=='{' || c=='}') return c.ToString();
            if(c!='"') throw new FormatException("Invalid Steam library format.");
            var s=new StringBuilder();
            while(p<text.Length) {
                c=text[p++]; if(c=='"') return s.ToString();
                if(c=='\\' && p<text.Length && (text[p]=='\\' || text[p]=='"')) c=text[p++];
                s.Append(c);
            }
            throw new FormatException("Unclosed Steam library string.");
        }
        static Vdf Read(string text,ref int p,bool nested,int depth) {
            if(depth>32) throw new FormatException("Steam library nesting too deep.");
            var node=new Vdf(); string key;
            while((key=Token(text,ref p))!=null) {
                if(key=="}") {if(nested)return node;throw new FormatException("Unexpected closing brace.");}
                if(key=="{") throw new FormatException("Unexpected opening brace.");
                string value=Token(text,ref p);
                if(value==null || value=="}") throw new FormatException("Missing Steam library value.");
                if(value=="{") node.children[key]=Read(text,ref p,true,depth+1); else node.values[key]=value;
            }
            if(nested) throw new FormatException("Unclosed Steam library object.");
            return node;
        }
        internal static Vdf Parse(string text) {int p=0;return Read(text,ref p,false,0);}
    }

    internal static class SteamLocator {
        internal const string AppId="4259190";
        internal static IEnumerable<string> Roots() {
            var roots=new List<string>();
            foreach(var hive in new[]{RegistryHive.CurrentUser,RegistryHive.LocalMachine})
            foreach(var view in new[]{RegistryView.Registry32,RegistryView.Registry64}) {
                try {
                    using(var key=RegistryKey.OpenBaseKey(hive,view))
                    using(var steam=key.OpenSubKey(@"Software\Valve\Steam")) {
                        if(steam!=null) foreach(var name in new[]{"SteamPath","InstallPath"}) {
                            string path=steam.GetValue(name) as string; if(!String.IsNullOrWhiteSpace(path)) roots.Add(path);
                        }
                    }
                } catch(System.Security.SecurityException) {} catch(UnauthorizedAccessException) {}
            }
            roots.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),"Steam"));
            return roots;
        }
        internal static List<string> Find(IEnumerable<string> roots) {
            var libraries=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var games=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(string raw in roots) {
                try {
                    string root=Path.GetFullPath(raw);libraries.Add(root);
                    string file=Path.Combine(root,"steamapps/libraryfolders.vdf");
                    if(File.Exists(file)) foreach(string p in Vdf.Parse(File.ReadAllText(file)).Child("libraryfolders").Paths()) libraries.Add(Path.GetFullPath(p));
                } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(ArgumentException) {} catch(FormatException) {}
            }
            foreach(string library in libraries) {
                try {
                    string common=Path.Combine(library,"steamapps/common");
                    string fallback=Path.Combine(common,"Kingdom Rush Genesis");
                    if(File.Exists(Path.Combine(fallback,"Kingdom Rush Genesis.exe"))) games.Add(fallback);
                    string file=Path.Combine(library,"steamapps/appmanifest_"+AppId+".acf");
                    if(!File.Exists(file)) continue;
                    var state=Vdf.Parse(File.ReadAllText(file)).Child("AppState");
                    string dir=state.Value("installdir");
                    if(state.Value("appid")!=AppId || String.IsNullOrWhiteSpace(dir) || Path.GetFileName(dir)!=dir || dir==".." || dir==".") continue;
                    string game=Path.Combine(common,dir);
                    if(File.Exists(Path.Combine(game,"Kingdom Rush Genesis.exe"))) games.Add(game);
                } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(ArgumentException) {} catch(FormatException) {}
            }
            var found=new List<string>(games);found.Sort(StringComparer.OrdinalIgnoreCase);return found;
        }
    }
}
