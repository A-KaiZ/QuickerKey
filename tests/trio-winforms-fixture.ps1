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
$list = New-Object System.Windows.Forms.ListView
$list.Dock = 'Fill'
$list.View = 'Details'
$list.FullRowSelect = $true
$names = @('Tidspunkt','Oppgave-ID','Telefonnr','T','E-post','Navn','Kundenummer','Tjeneste','Behandl.tid','Køtid','Koblet','Kategori','Kommentar')
$widths = @(190,130,80,30,80,80,100,100,90,70,70,70,120)
for ($i=0; $i -lt $names.Length; $i++) {
    [void]$list.Columns.Add($names[$i],$widths[$i])
}
for ($i=0; $i -lt 2052; $i++) {
    $day = if ($i -lt 2050) { (Get-Date).AddDays(-1) } else { Get-Date }
    $values = @(($day.ToString('dd.MM.yyyy') + ' 09:40:38'), ('98765' + $i.ToString('D5')), '', '', '', '', '', '', '02:30', '00:10', '', '', '')
    $item = [System.Windows.Forms.ListViewItem]::new([string[]]$values)
    [void]$list.Items.Add($item)
}
# Exercise displayed-to-logical column mapping at the same time.
$list.Columns[1].DisplayIndex = 4
$form.Controls.Add($list)
[System.Windows.Forms.Application]::Run($form)
