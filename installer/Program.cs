using System;
using System.IO;
using System.Drawing;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;

[assembly: AssemblyTitle("KR6 Better Economy Setup")]
[assembly: AssemblyDescription("Standalone installer for the unofficial KR6 economy plugin")]
[assembly: AssemblyCompany("WHUytfCN")]
[assembly: AssemblyProduct("KR6_Better_Economy")]
[assembly: AssemblyVersion("0.1.0.0")]
[assembly: AssemblyFileVersion("0.1.0.0")]
[assembly: AssemblyCopyright("Copyright (c) 2026 WHUytfCN")]

namespace KR6BetterEconomy {
    internal static class Program {
        internal static Payload LoadPayload() {
            var assembly=Assembly.GetExecutingAssembly();
            using(var zip=assembly.GetManifestResourceStream("payload.zip"))
            using(var manifest=assembly.GetManifestResourceStream("payload-manifest.json")) {
                if(zip==null || manifest==null) throw new InvalidDataException("安装包资源缺失，请从本项目的 Releases 页面重新下载。");
                return Payload.Read(zip,manifest);
            }
        }
        [STAThread] static int Main(string[] args) {
            try {
                if(args.Length==1 && args[0]=="--verify-package") {LoadPayload();return 0;}
                if(args.Length==2 && args[0]=="--inspect") {
                    var payload=LoadPayload();
                    File.WriteAllText(args[1],new JavaScriptSerializer().Serialize(new {version=payload.Build.version,files=payload.Files.Keys,detected=SteamLocator.Find(SteamLocator.Roots())}));return 0;
                }
                Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
                if(args.Length==2 && args[0]=="--preview") {
                    using(var form=new SetupForm(false)) {
                        form.Opacity=0;form.ShowInTaskbar=false;form.Show();Application.DoEvents();form.PerformLayout();
                        using(var bitmap=new Bitmap(form.Width,form.Height)) {form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(args[1]);}
                    }return 0;
                }
                using(var mutex=new Mutex(false,@"Local\KR6BetterEconomySetup")) {
                    bool acquired;try {acquired=mutex.WaitOne(0);} catch(AbandonedMutexException) {acquired=true;}
                    if(!acquired) {MessageBox.Show("另一个安装器正在运行。","KR6 Better Economy");return 1;}
                    try {Application.Run(new SetupForm());} finally {mutex.ReleaseMutex();}
                }
                return 0;
            } catch(Exception e) {
                if(args.Length==0) MessageBox.Show(e.Message,"安装器错误",MessageBoxButtons.OK,MessageBoxIcon.Error);
                return 1;
            }
        }
    }
    internal sealed class SetupForm : Form {
        readonly ComboBox location=new ComboBox();
        readonly Label status=new Label();
        readonly Button install=new Button(),browse=new Button(),detect=new Button(),open=new Button(),close=new Button();
        readonly CheckBox agree=new CheckBox();
        readonly ProgressBar progress=new ProgressBar();
        bool busy;
        string installed;
        static Label TextLabel(string text,float size,FontStyle style) {return new Label {Text=text,AutoSize=true,Font=new Font("Microsoft YaHei UI",size,style),Margin=new Padding(0,0,0,12),MaximumSize=new Size(670,0)};}
        internal SetupForm(bool autoDetect=true) {
            Text="KR6 Better Economy · 安装";Font=new Font("Microsoft YaHei UI",10F);
            AutoScaleMode=AutoScaleMode.Dpi;ClientSize=new Size(730,650);FormBorderStyle=FormBorderStyle.FixedDialog;
            MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;Padding=new Padding(24);
            var layout=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=1,RowCount=9};
            for(int i=0;i<8;i++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            Controls.Add(layout);
            layout.Controls.Add(TextLabel("KR6 Better Economy",22F,FontStyle.Bold));
            layout.Controls.Add(TextLabel("自由调整关卡金币收入，保留原版战斗与卖塔规则。\n非官方免费插件 · v0.1.0 · Windows / Steam",10F,FontStyle.Regular));
            layout.Controls.Add(TextLabel("选择游戏目录（包含 Kingdom Rush Genesis.exe）",10F,FontStyle.Bold));
            location.Dock=DockStyle.Fill;location.Margin=new Padding(0,0,0,10);layout.Controls.Add(location);
            var selectors=new FlowLayoutPanel {AutoSize=true,Dock=DockStyle.Fill,Margin=new Padding(0,0,0,12)};
            browse.Text="浏览…";detect.Text="重新查找";browse.AutoSize=detect.AutoSize=true;selectors.Controls.Add(browse);selectors.Controls.Add(detect);layout.Controls.Add(selectors);
            layout.Controls.Add(TextLabel("文件将安装到游戏目录下的 KR6_Better_Economy 文件夹。\n已有配置会保留。安装后双击 Start-Economy.cmd 启用。",10F,FontStyle.Regular));
            var licenseRow=new FlowLayoutPanel {AutoSize=true,Dock=DockStyle.Fill};
            agree.Text="我已阅读并同意非商业使用许可";agree.AutoSize=true;agree.Margin=new Padding(0,7,8,0);
            var license=new Button {Text="查看许可",AutoSize=true};licenseRow.Controls.Add(agree);licenseRow.Controls.Add(license);layout.Controls.Add(licenseRow);
            progress.Dock=DockStyle.Fill;progress.Height=12;progress.Margin=new Padding(0,10,0,10);layout.Controls.Add(progress);
            var bottom=new TableLayoutPanel {Dock=DockStyle.Fill,ColumnCount=1,RowCount=2};
            bottom.RowStyles.Add(new RowStyle(SizeType.Percent,100));bottom.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            status.Text="正在查找 Steam 游戏目录…";status.Dock=DockStyle.Fill;status.AutoSize=false;bottom.Controls.Add(status);
            var actions=new FlowLayoutPanel {AutoSize=true,Dock=DockStyle.Fill,FlowDirection=FlowDirection.RightToLeft};
            close.Text="关闭";install.Text="安装插件";open.Text="打开插件目录";open.Enabled=false;
            foreach(var b in new[]{close,install,open}) {b.AutoSize=true;b.Padding=new Padding(6);actions.Controls.Add(b);}
            bottom.Controls.Add(actions);layout.Controls.Add(bottom);
            install.Enabled=false;agree.CheckedChanged+=(s,e)=>install.Enabled=agree.Checked&&!busy;
            close.Click+=(s,e)=>Close();browse.Click+=(s,e)=>Browse();detect.Click+=async(s,e)=>await Detect();
            install.Click+=async(s,e)=>await Install();
            open.Click+=(s,e)=>{try {Process.Start("explorer.exe","\""+installed+"\"");}catch(Exception ex){MessageBox.Show(this,ex.Message);}};
            license.Click+=(s,e)=>ShowLicense();if(autoDetect)Shown+=async(s,e)=>await Detect();
            FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};
        }
        void SetBusy(bool value) {busy=value;browse.Enabled=detect.Enabled=close.Enabled=location.Enabled=agree.Enabled=!value;install.Enabled=!value&&agree.Checked;open.Enabled=!value&&installed!=null;progress.Style=value?ProgressBarStyle.Marquee:ProgressBarStyle.Blocks;}
        void Browse() {
            using(var dialog=new FolderBrowserDialog {Description="选择包含 Kingdom Rush Genesis.exe 的游戏目录",ShowNewFolderButton=false})
                if(dialog.ShowDialog(this)==DialogResult.OK) location.Text=dialog.SelectedPath;
        }
        async Task Detect() {
            SetBusy(true);status.Text="正在查找 Steam 游戏目录…";
            try {
                var paths=await Task.Run(()=>SteamLocator.Find(SteamLocator.Roots()));location.Items.Clear();
                foreach(string p in paths) location.Items.Add(p);
                if(paths.Count>0) {location.SelectedIndex=0;status.Text=paths.Count==1?"已找到游戏。确认目录后即可安装。":"找到多个游戏目录，请选择要安装的一份。";}
                else status.Text="未自动找到游戏。请点击“浏览…”选择游戏目录。";
            } catch(Exception e) {status.Text="自动查找失败，可手动浏览。";MessageBox.Show(this,e.Message);}
            finally {SetBusy(false);}
        }
        static bool Running() {
            var processes=Process.GetProcessesByName("Kingdom Rush Genesis");bool found=processes.Length>0;
            foreach(var p in processes)p.Dispose();return found;
        }
        async Task Install() {
            if(String.IsNullOrWhiteSpace(location.Text)) {status.Text="请先选择游戏目录。";return;}
            string selected=location.Text.Trim();SetBusy(true);status.Text="正在校验游戏并安装，请稍候…";
            try {
                await Task.Run(()=>InstallCore.Install(selected,Program.LoadPayload(),Running,null));
                installed=Path.Combine(Path.GetFullPath(selected),"KR6_Better_Economy");
                status.Text="安装完成！请打开插件目录，双击 Start-Economy.cmd 启动。\n普通 Steam 启动仍按原版运行。";
            } catch(UnauthorizedAccessException) {status.Text="没有写入权限。请使用可写的游戏目录，或关闭后明确以管理员身份重试。";}
            catch(Exception e) {status.Text="安装未完成。";MessageBox.Show(this,e.Message,"安装未完成",MessageBoxButtons.OK,MessageBoxIcon.Warning);}
            finally {SetBusy(false);}
        }
        void ShowLicense() {
            try {
                var payload=Program.LoadPayload();
                using(var dialog=new Form {Text="使用许可",Size=new Size(750,580),StartPosition=FormStartPosition.CenterParent}) {
                    dialog.Controls.Add(new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,Dock=DockStyle.Fill,Font=new Font("Consolas",10),Text=System.Text.Encoding.UTF8.GetString(payload.Files["LICENSE.md"])+"\r\n\r\n"+System.Text.Encoding.UTF8.GetString(payload.Files["NOTICE.md"])});
                    dialog.ShowDialog(this);
                }
            } catch(Exception e) {MessageBox.Show(this,e.Message,"无法读取许可");}
        }
    }
}
