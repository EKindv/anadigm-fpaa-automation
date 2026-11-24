# dialog_probe.ps1 -- identify every #32770 dialog AD2 puts up while a document is
# opened, and whether the automation call that triggered it returns.
#
#   powershell -File dialog_probe.ps1 -Doc <ad2> -WorkDir <dir>
#
# ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Doc,
    [Parameter(Mandatory = $true)][string]$WorkDir
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init (Join-Path $WorkDir 'dialog_probe.log')

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class DlgProbe {
    public delegate bool EP(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EP f, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EP f, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    public static string Dump() {
        var pids = new List<uint>();
        foreach (var p in System.Diagnostics.Process.GetProcessesByName("AD20")) pids.Add((uint)p.Id);
        var sb = new StringBuilder();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (!pids.Contains(pid)) return true;
            if (!IsWindowVisible(h)) return true;
            var c = new StringBuilder(128); GetClassName(h, c, 128);
            if (c.ToString() != "#32770") return true;
            var t = new StringBuilder(400); GetWindowText(h, t, 400);
            sb.Append("DLG title=[" + t.ToString() + "] buttons{");
            EnumChildWindows(h, delegate(IntPtr ch, IntPtr x) {
                var cc = new StringBuilder(64); GetClassName(ch, cc, 64);
                if (cc.ToString() != "Button") return true;
                int n = GetWindowTextLength(ch);
                if (n > 0) { var b = new StringBuilder(n + 2); GetWindowText(ch, b, n + 2); sb.Append("'" + b.ToString() + "' "); }
                return true;
            }, IntPtr.Zero);
            sb.Append("} ");
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
}
'@ -ErrorAction SilentlyContinue

# clean start
Get-Process AD20 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 1200

$app = New-Object -ComObject 'AnadigmDesigner2.Application'
$app.Visible = $true
AD2-Log '--- calling Document.Open ---'
$sw = [Diagnostics.Stopwatch]::StartNew()
try { $app.Document.Open($Doc, 0, $false, $false) } catch { AD2-Log ('  Open threw: ' + $_.Exception.Message.Split([char]10)[0]) }
$sw.Stop()
AD2-Log ('Document.Open returned after ' + [math]::Round($sw.Elapsed.TotalSeconds, 2) + ' s')

for ($i = 0; $i -lt 8; $i++) {
    $w = [DlgProbe]::Dump()
    AD2-Log ('  sweep ' + $i + ': ' + $(if ($w) { $w } else { '(no dialog)' }))
    Start-Sleep -Milliseconds 500
}
AD2-Log '--- can we still touch the object model? ---'
$sw2 = [Diagnostics.Stopwatch]::StartNew()
try { $n = $app.Workspace.Chips.Count; AD2-Log ('  Chips.Count=' + $n + ' in ' + [math]::Round($sw2.Elapsed.TotalSeconds, 2) + ' s') }
catch { AD2-Log ('  blocked: ' + $_.Exception.Message.Split([char]10)[0]) }
Get-Process AD20 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
