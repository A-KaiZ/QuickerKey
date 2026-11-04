using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

public sealed class FixtureForm : Form
{
    private readonly string mode;
    private int generation;
    public readonly ListView List = new ListView();
    public FixtureForm(string kind)
    {
        mode = kind; Text = "Oppgavelogg"; StartPosition = FormStartPosition.Manual;
        Location = new Point(80, 80); ClientSize = new Size(650, 300);
        List.View = View.Details; List.FullRowSelect = true; List.HideSelection = false;
        List.Location = new Point(0, 100); List.Size = new Size(650, 200);
        string[] columns = { "Tidspunkt", "Oppgave-ID", "Telefonnr", "T", "E-post", "Navn", "Kundenummer", "Tjeneste", "Behandl.tid", "Køtid", "Koblet", "Kategori", "Kommentar" };
        foreach (string column in columns) List.Columns.Add(column, 120);
        for (int i = 0; i < 8; i++) List.Items.Add(new ListViewItem(new string[] {
            DateTime.Today.ToString("dd.MM.yyyy") + " 09:10:11", "90000000" + i, "", "", "", "", "", "", "02:30", "00:10", "", "", "" }));
        Controls.Add(List);
        if (mode == "blank")
        {
            // Keep a real native handle/metadata, but genuinely render no list content.
            // A blank parent alone is insufficient: PrintWindow also renders visible children.
            List.Handle.ToInt64();
            List.Hide();
        }
        Shown += delegate { List.Items[2].Selected = true; List.Focus(); };
        if (mode == "native") List.Dock = DockStyle.Fill;
    }
    protected override void OnPaint(PaintEventArgs e) { base.OnPaint(e); DrawPrivate(e.Graphics); }
    private void DrawPrivate(Graphics graphics)
    {
        graphics.Clear(Color.White);
        graphics.FillRectangle(Brushes.Lime, 20, 20, 50, 40);
        graphics.FillRectangle(generation == 0 ? Brushes.Blue : Brushes.Red, 100, 20, 50, 40);
        graphics.DrawString("SYNTHETIC ONLY / generation " + generation, Font, Brushes.Black, 20, 70);
    }
    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x8015) { generation++; Invalidate(); message.Result = new IntPtr(1); return; }
        if ((message.Msg == 0x317 || message.Msg == 0x318) && mode != "native")
        {
            if (mode == "hang") Thread.Sleep(10000);
            using (Graphics graphics = Graphics.FromHdc(message.WParam))
            {
                if (mode == "blank") graphics.Clear(Color.White);
                else DrawPrivate(graphics);
            }
            message.Result = new IntPtr(1); return;
        }
        base.WndProc(ref message);
    }
}

public static class FixtureProgram
{
    [STAThread] public static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new FixtureForm(args.Length == 0 ? "paint" : args[0]));
    }
}
