using System;
using System.Drawing;
using System.Windows.Forms;
public static class OcrFixture
{
    [STAThread] public static void Main()
    {
        Application.EnableVisualStyles();
        Form form = new Form { Text = "Oppgavelogg", ClientSize = new Size(1200, 340), StartPosition = FormStartPosition.Manual, Location = new Point(10, 10) };
        ListView list = new ListView { Dock = DockStyle.Fill, View = View.Details, FullRowSelect = true, HideSelection = false, Font = new Font("Tahoma", 9) };
        string[] headers = { "Tidspunkt", "Oppgave-ID", "Telefonnr", "T", "E-post", "Navn", "Kundenummer", "Tjeneste", "Behandl.tid", "Køtid", "Koblet", "Kategori", "Kommentar" };
        int[] widths = { 180, 120, 55, 25, 55, 55, 70, 70, 90, 70, 70, 70, 100 };
        for (int i = 0; i < headers.Length; i++) list.Columns.Add(headers[i], widths[i]);
        for (int i = 0; i < 4; i++) list.Items.Add(new ListViewItem(new string[] { DateTime.Today.ToString("dd.MM.yyyy") + " 09:10:1" + i,
            (123456781 + i).ToString(), "", "", "", "", "", "", "02:30", "00:10", "", "", "" }));
        list.Items.Add(new ListViewItem(new string[] { DateTime.Today.AddDays(-1).ToString("dd.MM.yyyy") + " 09:10:10", "987654321", "", "", "", "", "", "", "10:00", "05:00", "", "", "" }));
        list.Columns[1].DisplayIndex = 3;
        form.Controls.Add(list);
        form.Shown += delegate { list.Items[1].Selected = true; list.Focus(); };
        Application.Run(form);
    }
}
