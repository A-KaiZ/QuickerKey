param([Parameter(Mandatory=$true)][long]$Hwnd, [Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NativeWindowCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
}
'@
$rect = [NativeWindowCapture+Rect]::new()
if (![NativeWindowCapture]::GetWindowRect([IntPtr]$Hwnd, [ref]$rect)) { throw 'Cannot get window rectangle' }
$bitmap = [Drawing.Bitmap]::new($rect.Right - $rect.Left, $rect.Bottom - $rect.Top)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$dc = $graphics.GetHdc()
try {
    if (![NativeWindowCapture]::PrintWindow([IntPtr]$Hwnd, $dc, 2)) { throw 'Cannot capture native window' }
} finally {
    $graphics.ReleaseHdc($dc)
    $graphics.Dispose()
}
try { $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png) }
finally { $bitmap.Dispose() }
