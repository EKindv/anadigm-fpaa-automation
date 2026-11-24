# suppress_dialogs.ps1 -- answer AD2's modal boxes from a SEPARATE process.
#
# This must run as its own process. The dialogs that matter appear while a COM
# call is on the stack (Document.Open, Simulator.Start), so the caller is blocked
# and cannot dismiss anything itself. Measured: opening chaos_v12.ad2 took 111.89 s
# because the "Not enough resources ... Do you want to keep these settings?" box
# sat unanswered until a human clicked it.
#
# What it answers:
#   Simulation Error            -> tick "Don't show this message again", then OK
#   any other #32770 with Yes/No -> click NO   (revert the settings that do not fit;
#                                   answering Yes keeps an over-committed design that
#                                   will then stall at Start - see PITFALLS 19)
#   any other #32770 with only OK -> click OK
# Never touched: the main frame (not a #32770), "Oscilloscope ...",
# "Set CAM Parameters" (the latter is a dialog a human may be using).
#
#   powershell -File suppress_dialogs.ps1 -Seconds 60 -LogFile x.log
#   powershell -File suppress_dialogs.ps1 -Seconds 60            (answers Yes)
#
# ASCII only.

param(
    [int]$Seconds = 60,
    [int]$IntervalMs = 250,
    [string]$LogFile = 'suppress_dialogs.log',
    [string]$ProcessName = 'AD20',
    [ValidateSet('No', 'Yes')][string]$YesNoAnswer = 'Yes',
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

    // answerYesNo: 2 = "No", 6 = "Yes" (the classic IDNO / IDYES values)
    public static string Sweep(string procName, int answerYesNo, bool wantOsc) {
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
            bool isOsc = title.IndexOf("Oscilloscope", StringComparison.OrdinalIgnoreCase) >= 0;
            bool isCam = title.IndexOf("Set CAM Parameters", StringComparison.OrdinalIgnoreCase) >= 0;
            if (isOsc && !wantOsc) return true;
            if (isCam) return true;

            IntPtr bDont = IntPtr.Zero, bOk = IntPtr.Zero, bYes = IntPtr.Zero, bNo = IntPtr.Zero;
            string sDont = "";
            EnumChildWindows(h, delegate(IntPtr c, IntPtr x) {
                var cc = new StringBuilder(128); GetClassName(c, cc, 128);
                if (cc.ToString() != "Button") return true;
                int n = GetWindowTextLength(c);
                if (n <= 0) return true;
                var buf = new StringBuilder(n + 2);
                GetWindowText(c, buf, n + 2);
                string s = buf.ToString().Trim();
                if (s.IndexOf("Don't show", StringComparison.OrdinalIgnoreCase) >= 0) { bDont = c; sDont = s; }
                else if (s.Equals("OK", StringComparison.OrdinalIgnoreCase)) bOk = c;
                else if (s.Equals("&Yes", StringComparison.OrdinalIgnoreCase) || s.Equals("Yes", StringComparison.OrdinalIgnoreCase)) bYes = c;
                else if (s.Equals("&No", StringComparison.OrdinalIgnoreCase) || s.Equals("No", StringComparison.OrdinalIgnoreCase)) bNo = c;
                return true;
            }, IntPtr.Zero);

            if (isErr) {
                if (bDont != IntPtr.Zero) { SendMessage(bDont, BM_CLICK, IntPtr.Zero, IntPtr.Zero); report.Append("ticked[" + sDont + "] "); }
                if (bOk != IntPtr.Zero) { SendMessage(bOk, BM_CLICK, IntPtr.Zero, IntPtr.Zero); report.Append("ok "); }
                else { PostMessage(h, WM_COMMAND, (IntPtr)1, IntPtr.Zero); report.Append("wm_ok "); }
            } else if (bYes != IntPtr.Zero || bNo != IntPtr.Zero) {
                IntPtr target = (answerYesNo == 6) ? bYes : bNo;
                string label = (answerYesNo == 6) ? "Yes" : "No";
                if (target != IntPtr.Zero) { SendMessage(target, BM_CLICK, IntPtr.Zero, IntPtr.Zero); }
                else { PostMessage(h, WM_COMMAND, (IntPtr)answerYesNo, IntPtr.Zero); }
                report.Append("answered[" + label + "] ");
            } else if (bOk != IntPtr.Zero) {
                SendMessage(bOk, BM_CLICK, IntPtr.Zero, IntPtr.Zero);
                report.Append("ok ");
            } else {
                return true;
            }
            report.Append("on[" + title + "] ");
            return true;
        }, IntPtr.Zero);
        return report.ToString();
    }
}
'@ -ErrorAction Stop

$ans = 2
if ($YesNoAnswer -ne 'No') { $ans = 6 }
$deadline = (Get-Date).AddSeconds($Seconds)
$answered = 0
while ((Get-Date) -lt $deadline) {
    try { $r = [Ad2Sup]::Sweep($ProcessName, $ans, [bool]$AlsoOscilloscope) } catch { $r = '' }
    if ($r) {
        $answered++
        Add-Content $LogFile ((Get-Date -Format 'HH:mm:ss.fff') + ' ' + $r) -Encoding UTF8
        Write-Output $r
    }
    Start-Sleep -Milliseconds $IntervalMs
}
Add-Content $LogFile ((Get-Date -Format 'HH:mm:ss.fff') + ' done, answered=' + $answered) -Encoding UTF8


