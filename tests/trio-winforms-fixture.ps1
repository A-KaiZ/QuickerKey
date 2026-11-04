param([switch]$AnsiOnly,[switch]$EmptyDraw)
# An actual .NET Framework ListView gets a WindowsForms10.SysListView32.*
# HWND class rather than the exact SysListView32 name of an AHK Gui control.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'QuickerKeys synthetic WinForms fixture'
$form.StartPosition = 'Manual'
$form.Location = New-Object System.Drawing.Point(0, 0)
$form.ClientSize = New-Object System.Drawing.Size(1450, 280)
if ($AnsiOnly) {
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Windows.Forms;
public class QuickerKeysAnsiOnlyListView : ListView {
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x1073) { m.Result = IntPtr.Zero; return; }
        base.WndProc(ref m);
    }
}
'@
    $list = New-Object QuickerKeysAnsiOnlyListView
} else {
    $list = New-Object System.Windows.Forms.ListView
}
$list.Dock = 'Fill'
$list.View = 'Details'
$list.FullRowSelect = $true
$names = @('Tidspunkt','Oppgave-ID','Telefonnr','T','E-post','Navn','Kundenummer','Tjeneste','Behandl.tid','Køtid','Koblet','Kategori','Kommentar')
$widths = @(190,130,80,30,80,80,100,100,90,70,70,70,120)
for ($i=0; $i -lt $names.Length; $i++) {
    [void]$list.Columns.Add($names[$i],$widths[$i])
}
$count = if ($AnsiOnly -or $EmptyDraw) { 3 } else { 2052 }
for ($i=0; $i -lt $count; $i++) {
    $day = if (($count -eq 2052 -and $i -lt 2050) -or ($count -eq 3 -and $i -eq 2)) { (Get-Date).AddDays(-1) } else { Get-Date }
    $values = @(($day.ToString('dd.MM.yyyy') + ' 09:40:38'), ('98765' + $i.ToString('D5')), '', '', '', '', '', '', '02:30', '00:10', '', '', '')
    if ($EmptyDraw) { $values = @('', '', '', '', '', '', '', '', '', '', '', '', '') }
    $item = [System.Windows.Forms.ListViewItem]::new([string[]]$values)
    [void]$list.Items.Add($item)
}
if ($EmptyDraw) {
    # Text is painted from private state, not stored as ListView strings.
    $list.OwnerDraw = $true
    $list.add_DrawColumnHeader({ param($sender,$e) $e.DrawDefault = $true })
    $list.add_DrawItem({ param($sender,$e) $e.DrawBackground() })
    $list.add_DrawSubItem({
        param($sender,$e)
        $display = if ($e.ColumnIndex -eq 0) { (Get-Date).ToString('dd.MM.yyyy') + ' 09:40:38' }
            elseif ($e.ColumnIndex -eq 1) { '9876500001' } elseif ($e.ColumnIndex -eq 8) { '02:30' } else { '' }
        $e.Graphics.DrawString($display,$sender.Font,[System.Drawing.Brushes]::Black,[single]$e.Bounds.X,[single]$e.Bounds.Y)
    })
}
# Exercise displayed-to-logical column mapping at the same time.
$list.Columns[1].DisplayIndex = 4
$form.Controls.Add($list)
[System.Windows.Forms.Application]::Run($form)
