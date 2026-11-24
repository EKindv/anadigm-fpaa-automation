# suppress_dialogs.ps1 -- turn off AD2's repeating modal error boxes, once.
#
# The "Simulation Error" dialog carries a button labelled
#   "Don't show this message again.  (reset in display preferences)"
# Ticking it and pressing OK stops AD2 from raising that modal box again, which is
# the difference between "the simulation is wedged behind a dialog" and
# "the simulation simply did not start, and the automation keeps working".
#
# Run this once per machine, while at least one Simulation Error dialog is on
# screen. Afterwards scripts can detect a failed start instead of fighting a modal.
#
#   powershell -File suppress_dialogs.ps1 -Seconds 60
#
# ASCII only.

param(
    [int]$Seconds = 60,
    [string]$LogFile = 'suppress_dialogs.log',
    [string]$ProcessName = 'AD20',
    [switch]$AlsoOscilloscope
)

$ErrorActionPreference = 'Continue'

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Ad2Sup {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);

    const uint BM_CLICK = 0x00F5;
    const uint WM_COMMAND = 0x0111;

    // returns a description of what was done, empty if nothing matched
    public static string Suppress(string procName, bool wantOsc) {
        var pids = new List<uint>();
        foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(procName))
            pids.Add((uint)p.Id);
        if (pids.Count == 0) return "";
        var report = new StringBuilder();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (!pids.Contains(pid)) return true;
            if (!IsWindowVisible(h)) return true;
            var cls = new StringBuilder(128); GetClassName(h, cls, 128);
            if (cls.ToString() != "#32770") return true;
            var t = new StringBuilder(400); GetWindowText(h, t, 400);
            string title = t.ToString();
            bool isErr = title.IndexOf("Simulation Error", StringComparison.OrdinalIgnoreCase) >= 0;
            bool isOsc = wantOsc && title.IndexOf("Oscilloscope", StringComparison.OrdinalIgnoreCase) >= 0;
            if (!isErr && !isOsc) return true;

            IntPtr dontShow = IntPtr.Zero, ok = IntPtr.Zero;
            string dontShowText = "", okText = "";
            EnumChildWindows(h, delegate(IntPtr c, IntPtr x) {
                var cc = new StringBuilder(128); GetClassName(c, cc, 128);
                if (cc.ToString() != "Button") return true;
                int n = GetWindowTextLength(c);
                if (n <= 0) return true;
                var buf = new StringBuilder(n + 2);
                GetWindowText(c, buf, n + 2);
                string s = buf.ToString();
                if (s.IndexOf("Don't show", StringComparison.OrdinalIgnoreCase) >= 0) { dontShow = c; dontShowText = s; }
                if (s.Trim().Equals("OK", StringComparison.OrdinalIgnoreCase)) { ok = c; okText = s; }
                return true;
            }, IntPtr.Zero);

            if (isErr) {
                if (dontShow != IntPtr.Zero) {
                    SendMessage(dontShow, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                    report.Append("ticked[" + dontShowText + "] ");
                }
                if (ok != IntPtr.Zero) {
                    SendMessage(ok, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                    report.Append("ok[" + okText + "] ");
                } else {
                    PostMessage(h, WM_COMMAND, (IntPtr)1, IntPtr.Zero);
                    report.Append("wm_ok ");
                }
                report.Append("on[" + title + "] ");
            }
            return true;
        }, IntPtr.Zero);
        return report.ToString();
    }
}
'@ -ErrorAction SilentlyContinue

$deadline = (Get-Date).AddSeconds($Seconds)
$done = $false
while ((Get-Date) -lt $deadline -and -not $done) {
    try { $r = [Ad2Sup]::Suppress($ProcessName, [bool]$AlsoOscilloscope) } catch { $r = '' }
    if ($r) {
        Add-Content $LogFile ((Get-Date -Format 'HH:mm:ss.fff') + ' ' + $r) -Encoding UTF8
        Write-Output $r
        $done = $true
    } else {
        Start-Sleep -Milliseconds 500
    }
}
if (-not $done) {
    Add-Content $LogFile ((Get-Date -Format 'HH:mm:ss.fff') + ' no Simulation Error dialog found') -Encoding UTF8
    Write-Output 'no Simulation Error dialog found'
}
