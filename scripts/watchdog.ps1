# watchdog.ps1 -- keep AnadigmDesigner2 from wedging itself behind modal dialogs.
#
# AD2 raises modal dialogs for almost every error (resource exhaustion, an
# unconnected pin, a zero-delay loop). While a modal dialog is up the automation
# server answers NOTHING, so a headless script hangs forever instead of throwing.
# This keeps closing them every 400 ms from a separate process.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File watchdog.ps1 [-Seconds 600] [-LogFile path]
#
# ASCII only.

param(
    [int]$Seconds = 400,
    [string]$LogFile = '',
    [string]$ProcessName = 'AD20'
)

$ErrorActionPreference = 'Continue'

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Ad2Watchdog {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    public static string Sweep(string procName) {
        var found = new StringBuilder();
        var pids = new List<uint>();
        foreach (System.Diagnostics.Process p in System.Diagnostics.Process.GetProcessesByName(procName))
            pids.Add((uint)p.Id);
        if (pids.Count == 0) return "";
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (!pids.Contains(pid)) return true;
            if (!IsWindowVisible(h)) return true;
            var cls = new StringBuilder(128); GetClassName(h, cls, 128);
            if (cls.ToString() != "#32770") return true;          // only real dialogs
            var txt = new StringBuilder(300); GetWindowText(h, txt, 300);
            string title = txt.ToString();
            // never close the windows we want to watch
            if (title.IndexOf("Oscilloscope", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            if (title.IndexOf("AnadigmDesigner", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            if (title.IndexOf("Set CAM", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            found.Append(title + " ; ");
            PostMessage(h, 0x0100, (IntPtr)0x1B, IntPtr.Zero);     // WM_KEYDOWN ESC
            PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero);      // WM_CLOSE
            return true;
        }, IntPtr.Zero);
        return found.ToString();
    }
}
'@ -ErrorAction SilentlyContinue

if ($LogFile) {
    Add-Content -Path $LogFile -Value ((Get-Date -Format 'HH:mm:ss') + ' watchdog started') -Encoding UTF8
}

$deadline = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
    try { $closed = [Ad2Watchdog]::Sweep($ProcessName) } catch { $closed = '' }
    if ($closed -and $LogFile) {
        Add-Content -Path $LogFile -Value ((Get-Date -Format 'HH:mm:ss') + ' closed ' + $closed) -Encoding UTF8
    }
    Start-Sleep -Milliseconds 400
}

if ($LogFile) {
    Add-Content -Path $LogFile -Value ((Get-Date -Format 'HH:mm:ss') + ' watchdog exit') -Encoding UTF8
}
