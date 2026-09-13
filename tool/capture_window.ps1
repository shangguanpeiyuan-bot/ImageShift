param([Parameter(Mandatory=$true)][int]$AppProcessId,
      [Parameter(Mandatory=$true)][string]$OutputPath,
      [int]$Width=1280, [int]$Height=900)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ImageShiftWindowCapture {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr window,int x,int y,int width,int height,bool repaint);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window,int command);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[ImageShiftWindowCapture]::SetProcessDPIAware() | Out-Null
$app = Get-Process -Id $AppProcessId
if ($app.ProcessName -ne 'imageshift' -or $app.MainWindowHandle -eq 0) { throw 'Expected a visible ImageShift window.' }
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$widthActual = [Math]::Min($Width, $screen.Width-30)
$heightActual = [Math]::Min($Height, $screen.Height-30)
[ImageShiftWindowCapture]::ShowWindow($app.MainWindowHandle,9) | Out-Null
[ImageShiftWindowCapture]::MoveWindow($app.MainWindowHandle,$screen.Left+15,$screen.Top+15,$widthActual,$heightActual,$true) | Out-Null
[ImageShiftWindowCapture]::SetForegroundWindow($app.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700
$rect = New-Object ImageShiftWindowCapture+RECT
[ImageShiftWindowCapture]::GetWindowRect($app.MainWindowHandle,[ref]$rect) | Out-Null
$bitmap = New-Object System.Drawing.Bitmap(($rect.Right-$rect.Left),($rect.Bottom-$rect.Top))
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
  $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
  $bitmap.Save([IO.Path]::GetFullPath($OutputPath),[System.Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $bitmap.Dispose() }
[pscustomobject]@{ProcessId=$AppProcessId;Left=$rect.Left;Top=$rect.Top;Width=$widthActual;Height=$heightActual;Screenshot=[IO.Path]::GetFullPath($OutputPath)} | ConvertTo-Json
