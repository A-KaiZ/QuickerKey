using System;
using System.Drawing;
using System.Windows.Forms;
public static class OcrFixture
{
    [STAThread] public static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Form form = new Form { Text = "Oppgavelogg", ClientSize = new Size(1200, 340), StartPosition = FormStartPosition.Manual, Location = new Point(10, 10) };
        ListView list = new ListView { Dock = DockStyle.Fill, View = View.Details, FullRowSelect = true, HideSelection = false, Font = new Font("Tahoma", 9) };
        bool nativeText = args.Length == 1 && args[0] == "--native-text";
        list.OwnerDraw = !nativeText;
        System.Collections.Generic.List<string[]> privateRows = new System.Collections.Generic.List<string[]>();
        list.DrawColumnHeader += delegate(object sender, DrawListViewColumnHeaderEventArgs e) { e.DrawDefault = true; };
        list.DrawItem += delegate(object sender, DrawListViewItemEventArgs e) { e.DrawBackground(); };
        list.DrawSubItem += delegate(object sender, DrawListViewSubItemEventArgs e) {
            bool selected = e.Item.Selected;
            e.Graphics.FillRectangle(selected ? SystemBrushes.Highlight : Brushes.White, e.Bounds);
            TextRenderer.DrawText(e.Graphics, privateRows[e.ItemIndex][e.ColumnIndex], list.Font, e.Bounds,
                selected ? SystemColors.HighlightText : Color.Black, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix);
        };
        string[] headers = { "Tidspunkt", "Oppgave-ID", "Telefonnr", "T", "E-post", "Navn", "Kundenummer", "Tjeneste", "Behandl.tid", "Køtid", "Koblet", "Kategori", "Kommentar" };
        int[] widths = { 180, 120, 55, 25, 55, 55, 70, 70, 90, 70, 70, 70, 100 };
        for (int i = 0; i < headers.Length; i++) list.Columns.Add(headers[i], widths[i]);
        for (int i = 0; i < 4; i++) privateRows.Add(new string[] { DateTime.Today.ToString("dd.MM.yyyy") + " 09:10:1" + i,
            (123456781 + i).ToString(), "", "", "", "", "", "", "02:30", "00:10", "", "", "" });
        privateRows.Add(new string[] { DateTime.Today.AddDays(-1).ToString("dd.MM.yyyy") + " 09:10:10", "987654321", "", "", "", "", "", "", "10:00", "05:00", "", "", "" });
        foreach (string[] row in privateRows) list.Items.Add(new ListViewItem(nativeText ? row : new string[] { "", "", "", "", "", "", "", "", "", "", "", "", "" }));
        list.Columns[1].DisplayIndex = 3;
        form.Controls.Add(list);
        form.Shown += delegate { list.Items[1].Selected = true; list.Focus(); };
        Application.Run(form);
    }
}
