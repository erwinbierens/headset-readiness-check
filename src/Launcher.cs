using System;
using System.IO;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;
class Program {
 [STAThread] static int Main(string[] args) {
  string dir=Path.Combine(Path.GetTempPath(),"EspritICTBluetoothCheck",Guid.NewGuid().ToString("N"));
  try {
   Directory.CreateDirectory(dir);
   foreach(string name in new[]{"App.ps1","Collect.ps1","esprit-ict-logo.png","esprit-ict.ico"})
    using(var s=Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
    using(var f=File.Create(Path.Combine(dir,name))) s.CopyTo(f);
   var p=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"));
   p.Arguments="-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File \""+Path.Combine(dir,"App.ps1")+"\"";
   p.UseShellExecute=false;p.CreateNoWindow=true;
   using(var child=Process.Start(p)){child.WaitForExit();return child.ExitCode;}
  } catch(Exception e){MessageBox.Show(e.Message,"Esprit ICT Bluetooth Check");return 1;}
  finally{try{Directory.Delete(dir,true);}catch{}}
 }
}
