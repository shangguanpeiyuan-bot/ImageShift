param([Parameter(Mandatory=$true)][int]$AppProcessId,
      [ValidateSet('Click','Keys','Inspect','Edits','SetEdit','PressButton')][string]$Action='Inspect',
      [int]$X=0,[int]$Y=0,[string]$Keys='',[long]$EditHandle=0)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class ImageShiftUiAction {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr window,uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window,out RECT rect);
  public delegate bool EnumProc(IntPtr window, IntPtr param);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr param);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr window,StringBuilder name,int max);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window,StringBuilder text,int max);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool SetWindowText(IntPtr window,string text);
  [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] public static extern IntPtr SetControlText(IntPtr window,uint message,IntPtr unused,string text);
  [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] public static extern IntPtr ReadControlText(IntPtr window,uint message,IntPtr length,StringBuilder text);
  [DllImport("user32.dll")] public static extern bool IsChild(IntPtr parent,IntPtr child);
  public static List<string[]> Edits(IntPtr parent) {
    var list=new List<string[]>();
    EnumChildWindows(parent,(window,param)=>{
      var name=new StringBuilder(128); GetClassName(window,name,128);
      if(name.ToString()=="Edit") { var text=new StringBuilder(2048); GetWindowText(window,text,2048); RECT rect; GetWindowRect(window,out rect); list.Add(new[]{window.ToInt64().ToString(),name.ToString(),text.ToString(),rect.Left+","+rect.Top+","+rect.Right+","+rect.Bottom}); }
      return true;
    },IntPtr.Zero);
    return list;
  }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
}
'@
[ImageShiftUiAction]::SetProcessDPIAware() | Out-Null
$window=[ImageShiftUiAction]::GetForegroundWindow()
[uint32]$foregroundPid=0
[ImageShiftUiAction]::GetWindowThreadProcessId($window,[ref]$foregroundPid) | Out-Null
if($foregroundPid -ne $AppProcessId) { throw "Foreground belongs to another process ($foregroundPid); no input was sent." }
switch($Action) {
  'PressButton' {
    $button=[IntPtr]::new($EditHandle)
    [uint32]$targetPid=0
    [ImageShiftUiAction]::GetWindowThreadProcessId($button,[ref]$targetPid) | Out-Null
    if($targetPid -ne $AppProcessId) { throw 'Button belongs to another process.' }
    [ImageShiftUiAction]::SetForegroundWindow([ImageShiftUiAction]::GetAncestor($button,2)) | Out-Null
    [ImageShiftUiAction]::SetControlText($button,245,[IntPtr]::Zero,$null) | Out-Null
  }
  'Edits' { [ImageShiftUiAction]::Edits($window) | ConvertTo-Json -Depth 3 }
  'SetEdit' {
    $edit=[IntPtr]::new($EditHandle)
    [uint32]$targetPid=0
    [ImageShiftUiAction]::GetWindowThreadProcessId($edit,[ref]$targetPid) | Out-Null
    if($targetPid -ne $AppProcessId) { throw 'Edit belongs to another process.' }
    [ImageShiftUiAction]::SetForegroundWindow([ImageShiftUiAction]::GetAncestor($edit,2)) | Out-Null
    [ImageShiftUiAction]::SetControlText($edit,12,[IntPtr]::Zero,$Keys) | Out-Null
    $actual=New-Object System.Text.StringBuilder(4096)
    [ImageShiftUiAction]::ReadControlText($edit,13,[IntPtr]::new(4096),$actual) | Out-Null
    if($actual.ToString() -ne $Keys) { throw 'The native file field did not accept the exact requested value.' }
  }
  'Click' {
    [System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point($X,$Y)
    [ImageShiftUiAction]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    [ImageShiftUiAction]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  }
  'Keys' { [System.Windows.Forms.SendKeys]::SendWait($Keys) }
  'Inspect' {
    $element=[System.Windows.Automation.AutomationElement]::FromHandle($window)
    $elements=$element.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    $result=foreach($item in $elements) {
      if($item.Current.Name -or $item.Current.ControlType.ProgrammaticName -eq 'ControlType.Edit') {
        [pscustomobject]@{Name=$item.Current.Name;Type=$item.Current.ControlType.ProgrammaticName;Bounds=$item.Current.BoundingRectangle.ToString();AutomationId=$item.Current.AutomationId}
      }
    }
    $result | ConvertTo-Json -Depth 3
  }
}
