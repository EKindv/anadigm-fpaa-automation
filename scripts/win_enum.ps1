# win_enum.ps1 -- dump EVERY top-level window that mentions Anadigm, whatever its
# process, plus every child of the main frame. Used to find out what the blocking
# "Not enough resources ... Do you want to keep these settings?" box actually is.
#
#   powershell -File win_enum.ps1 -OutFile x.txt
#
# ASCII only.

param([string]$OutFile = 'win_enum.txt')

$ErrorActionPreference = 'Continue'
$code = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinEnum {
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP f, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EP f, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    public static string All() {
        var sb = new StringBuilder();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            var t = new StringBuilder(300); GetWindowText(h, t, 300);
            var c = new StringBuilder(128); GetClassName(h, c, 128);
            uint pid; GetWindowThreadProcessId(h, out pid);
            string title = t.ToString();
            bool interesting = title.IndexOf("Anadigm", StringComparison.OrdinalIgnoreCase) >= 0
                            || title.IndexOf("resource", StringComparison.OrdinalIgnoreCase) >= 0
                            || c.ToString() == "#32770";
            if (!interesting) return true;
            string pname = "?";
            try { pname = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch { }
            sb.Append("TOP pid=" + pid + " proc=" + pname + " cls=" + c + " vis=" + IsWindowVisible(h)
                      + " en=" + IsWindowEnabled(h) + " owner=" + GetWindow(h, 4) + " title=[" + title + "]\n");
            EnumChildWindows(h, delegate(IntPtr ch, IntPtr x) {
                var ct = new StringBuilder(300); GetWindowText(ch, ct, 300);
                var cc = new StringBuilder(128); GetClassName(ch, cc, 128);
                if (ct.Length > 0)
                    sb.Append("    child cls=" + cc + " text=[" + ct.ToString() + "]\n");
                return true;
            }, IntPtr.Zero);
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
}
'@
$err = $null
Add-Type -TypeDefinition $code -ErrorAction Stop 2>&1 | Out-Null
if ($?) { "type compiled OK" | Out-File $OutFile -Encoding UTF8 }
else { "COMPILE FAILED: $err" | Out-File $OutFile -Encoding UTF8 }
for ($i = 0; $i -lt 6; $i++) {
    try { [WinEnum]::All() | Out-File $OutFile -Append -Encoding UTF8 } catch { "enum failed: $_" | Out-File $OutFile -Append -Encoding UTF8 }
    Start-Sleep -Milliseconds 700
}
