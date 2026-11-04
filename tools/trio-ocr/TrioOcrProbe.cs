using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using QuickerKeys.CaptureProbe;

namespace QuickerKeys.Ocr
{
    public sealed class Frame
    {
        public Layout Layout;
        public CaptureResult Image;
        public void Clear() { if (Image != null) Image.ClearPixels(); }
    }
    public static class FrameWorker
    {
        private static void WriteRectangle(BinaryWriter writer, Rectangle r)
        { writer.Write(r.X); writer.Write(r.Y); writer.Write(r.Width); writer.Write(r.Height); }
        private static Rectangle ReadRectangle(BinaryReader reader)
        { return new Rectangle(reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32()); }
        public static Frame Capture(Target target)
        {
            IntPtr list; Native.Rect before, after;
            if (!Discovery.Validate(target, out list) || !Native.GetWindowRect(target.Window, out before))
                return new Frame { Image = new CaptureResult { Status = CaptureStatus.TargetChanged } };
            if (Native.IsIconic(target.Window)) return new Frame { Image = new CaptureResult { Status = CaptureStatus.Minimized } };
            if (!Native.ActiveDesktop()) return new Frame { Image = new CaptureResult { Status = CaptureStatus.SessionUnavailable } };
            Layout layout = LayoutReader.Read(list, before);
            if (layout == null) return new Frame { Image = new CaptureResult { Status = CaptureStatus.MetadataUnavailable } };
            CaptureResult image = CaptureWorker.Capture(target);
            if (image.Status != CaptureStatus.Image) return new Frame { Image = image };
            try
            {
                Layout current = LayoutReader.Read(list, before);
                if (!Native.GetWindowRect(target.Window, out after) || !before.Same(after) || current == null
                    || layout.Fingerprint() != current.Fingerprint() || !layout.Valid(image.Width, image.Height))
                { image.ClearPixels(); return new Frame { Image = new CaptureResult { Status = CaptureStatus.LayoutChanged } }; }
                return new Frame { Image = image, Layout = layout };
            }
            catch { image.ClearPixels(); throw; }
        }
        public static void Write(Stream stream, Frame frame)
        {
            using (BinaryWriter writer = new BinaryWriter(stream, Encoding.UTF8, true))
            {
                writer.Write(0x31434F51); writer.Write(frame.Layout != null);
                if (frame.Layout != null)
                {
                    WriteRectangle(writer, frame.Layout.Body); writer.Write(frame.Layout.Columns.Count);
                    foreach (var column in frame.Layout.Columns) { writer.Write((int)column.Key); WriteRectangle(writer, column.Value); }
                    writer.Write(frame.Layout.Rows.Count);
                    foreach (Rectangle row in frame.Layout.Rows) WriteRectangle(writer, row);
                }
                writer.Flush();
            }
            CaptureWorker.Write(stream, frame.Image);
        }
        public static Frame Read(Stream stream)
        {
            Layout layout = null;
            using (BinaryReader reader = new BinaryReader(stream, Encoding.UTF8, true))
            {
                if (reader.ReadInt32() != 0x31434F51) throw new InvalidDataException();
                if (reader.ReadBoolean())
                {
                    layout = new Layout { Body = ReadRectangle(reader) };
                    int count = reader.ReadInt32();
                    if (count < 2 || count > 4) throw new InvalidDataException();
                    for (int i = 0; i < count; i++)
                    {
                        int key = reader.ReadInt32();
                        if (!Enum.IsDefined(typeof(Field), key) || layout.Columns.ContainsKey((Field)key)) throw new InvalidDataException();
                        layout.Columns.Add((Field)key, ReadRectangle(reader));
                    }
                    int rows = reader.ReadInt32();
                    if (rows < 0 || rows > 1000) throw new InvalidDataException();
                    for (int i = 0; i < rows; i++) layout.Rows.Add(ReadRectangle(reader));
                }
            }
            CaptureResult image = CaptureWorker.Read(stream);
            if (image.Status == CaptureStatus.Image && (layout == null || !layout.Valid(image.Width, image.Height)))
            { image.ClearPixels(); throw new InvalidDataException(); }
            return new Frame { Image = image, Layout = layout };
        }
        public static async Task<Frame> Run(string executable, Target target, CancellationToken cancel)
        {
            ProcessStartInfo start = new ProcessStartInfo(executable, "--ocr-worker " + target.Window.ToInt64() + " " + target.ProcessId + " " + target.ProcessStartUtc);
            start.UseShellExecute = false; start.CreateNoWindow = true; start.RedirectStandardOutput = true; start.RedirectStandardError = true;
            using (Process worker = new Process { StartInfo = start })
            {
                Task<Frame> reading = null; bool accepted = false;
                try
                {
                    cancel.ThrowIfCancellationRequested(); worker.Start();
                    reading = Task.Run(delegate { return Read(worker.StandardOutput.BaseStream); });
                    if (await Task.WhenAny(reading, Task.Delay(7000, cancel)).ConfigureAwait(false) != reading)
                        return new Frame { Image = new CaptureResult { Status = cancel.IsCancellationRequested ? CaptureStatus.Cancelled : CaptureStatus.Timeout } };
                    Frame result = await reading.ConfigureAwait(false);
                    if (cancel.IsCancellationRequested) { result.Clear(); return new Frame { Image = new CaptureResult { Status = CaptureStatus.Cancelled } }; }
                    accepted = true; return result;
                }
                catch (OperationCanceledException) { return new Frame { Image = new CaptureResult { Status = CaptureStatus.Cancelled } }; }
                catch { return new Frame { Image = new CaptureResult { Status = CaptureStatus.ProtocolError } }; }
                finally
                {
                    try { if (!worker.HasExited) worker.Kill(); worker.WaitForExit(500); } catch { }
                    if (reading != null) Observe(reading, accepted);
                }
            }
        }
        private static void Observe(Task<Frame> reading, bool accepted)
        {
            reading.ContinueWith(delegate(Task<Frame> task) {
                if (task.Status == TaskStatus.RanToCompletion && !accepted) task.Result.Clear();
                if (task.IsFaulted) { var ignored = task.Exception; }
            }, TaskScheduler.Default);
        }
    }

    public static class OcrProgram
    {
        public const string Version = "P1.0";
        [STAThread] public static int Main(string[] args)
        {
            Native.SetDpiMode();
            if (args.Length > 0 && args[0] == "--worker") return QuickerKeys.CaptureProbe.Program.Main(args);
            if (args.Length > 0)
            {
                if (args.Length != 4 || args[0] != "--ocr-worker") return 2;
                new Thread(delegate() { Thread.Sleep(8000); Environment.Exit(3); }) { IsBackground = true }.Start();
                Frame frame;
                try
                {
                    Target target = new Target { Window = new IntPtr(Int64.Parse(args[1])), ProcessId = Int32.Parse(args[2]), ProcessStartUtc = Int64.Parse(args[3]) };
                    frame = Task.Run(delegate { return FrameWorker.Capture(target); }).GetAwaiter().GetResult();
                }
                catch { frame = new Frame { Image = new CaptureResult { Status = CaptureStatus.MetadataUnavailable } }; }
                try { FrameWorker.Write(Console.OpenStandardOutput(), frame); }
                catch { return 2; }
                finally { frame.Clear(); }
                return 0;
            }
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new OcrForm()); return 0;
        }
    }
    public sealed class OcrForm : Form
    {
        private Target target;
        private readonly CancellationTokenSource lifetime = new CancellationTokenSource();
        private CancellationTokenSource pending;
        private readonly Label status = new Label();
        private readonly TextBox result = new TextBox();
        private readonly List<Button> actions = new List<Button>();
        private string diagnostic = "Ingen OCR-prøve kjørt.";
        private bool busy;
        public OcrForm()
        {
            Text = "QuickerKeys · Trio OCR-test " + OcrProgram.Version;
            ClientSize = new Size(850, 600); MinimumSize = new Size(760, 540);
            Font = new Font("Segoe UI", 10); StartPosition = FormStartPosition.CenterScreen;
            TableLayoutPanel panel = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4, Padding = new Padding(16) };
            panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 92)); panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
            panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 44)); panel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            panel.Controls.Add(new Label { Dock = DockStyle.Fill, Text = "Eksperimentell innlesing fra dagens synlige rader.\r\nUIA gir bare overskrifter/plassering; Tesseract leser fire bildefelt lokalt.\r\nFaktisk Trio-bakgrunnsfangst er ikke bekreftet. Ingen automatisk oppdatering eller import til dashboard." }, 0, 0);
            FlowLayoutPanel buttons = new FlowLayoutPanel { Dock = DockStyle.Fill };
            Button find = AddButton(buttons, "Finn Oppgavelogg"); find.Click += async delegate { await Find(); };
            Button read = AddButton(buttons, "Les utsnitt (5 s)"); read.Click += async delegate { await Read(); };
            Button capture = AddButton(buttons, "Test bildehenting"); capture.Click += delegate {
                string exe = Path.Combine(Application.StartupPath, "TrioCaptureProbe.exe");
                if (File.Exists(exe)) Process.Start(exe); else status.Text = "Fangstverktøyet mangler i pakken.";
            };
            Button copy = AddButton(buttons, "Kopier anonym diagnose"); copy.Click += delegate {
                try { Clipboard.SetText(diagnostic); status.Text = "Anonym diagnose kopiert."; } catch { status.Text = "Utklippstavlen er opptatt."; }
            };
            Button cancel = new Button { Text = "Avbryt", AutoSize = true }; cancel.Click += delegate { if (pending != null) pending.Cancel(); }; buttons.Controls.Add(cancel);
            panel.Controls.Add(buttons, 0, 1); status.Dock = DockStyle.Fill; status.Text = "Finn loggvinduet for å starte en prøve."; panel.Controls.Add(status, 0, 2);
            result.Dock = DockStyle.Fill; result.Multiline = true; result.ReadOnly = true; result.ScrollBars = ScrollBars.Vertical;
            result.Text = "Ingen lesbare data er bekreftet ennå.\r\nIngen oppgaver telles før dato, ID og radplassering passer sammen.";
            panel.Controls.Add(result, 0, 3); Controls.Add(panel);
        }
        private Button AddButton(Control panel, string text)
        {
            Button button = new Button { Text = text, AutoSize = true, Margin = new Padding(0, 0, 8, 6) };
            panel.Controls.Add(button); actions.Add(button); return button;
        }
        private void Busy(bool value) { busy = value; foreach (Button button in actions) button.Enabled = !value; }
        private async Task Find()
        {
            if (busy) return; Busy(true);
            try
            {
                List<Target> found = await Task.Run(delegate { return Discovery.Find(); });
                if (IsDisposed) return; target = found.Count == 1 ? found[0] : null;
                status.Text = target == null ? "Fant " + found.Count + " passende loggvinduer. Trenger ett." : "Oppgavelogg funnet. Klar for én OCR-prøve.";
            }
            catch { if (!IsDisposed) status.Text = "Vindussøket feilet. Ingen rå feildata er lagret."; }
            finally { if (!IsDisposed) Busy(false); }
        }
        private async Task Read()
        {
            if (busy) return;
            if (target == null) { status.Text = "Finn Oppgavelogg først."; return; }
            Busy(true); pending = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
            Frame frame = null; DateTime date = DateTime.Today; Stopwatch elapsed = Stopwatch.StartNew();
            diagnostic = "OCR-prøve startet; ingen nytt resultat bekreftet.";
            result.Text = "Venter på nytt utsnitt…";
            try
            {
                for (int seconds = 5; seconds > 0; seconds--) { status.Text = "Leser om " + seconds + " s. Loggen kan dekkes, men ikke minimeres."; await Task.Delay(1000, pending.Token); }
                status.Text = "Henter bilde og kolonne-/radplassering…";
                frame = await FrameWorker.Run(Application.ExecutablePath, target, pending.Token);
                if (IsDisposed) return;
                if (frame.Image.Status != CaptureStatus.Image)
                {
                    diagnostic = "QuickerKeys Trio OCR " + OcrProgram.Version + "\r\nFangst/layout: " + frame.Image.Status + "\r\nIngen ny OCR-avlesning godkjent. Ingen rå verdier inkludert.";
                    result.Text = diagnostic; status.Text = "Fangst eller layout kunne ikke brukes."; return;
                }
                status.Text = "Leser dato, ID og tidskolonner lokalt…";
                Reader reader = new Reader(new Engine(Path.Combine(Application.StartupPath, "ocr")));
                Report report = await Task.Run(delegate { return reader.Read(frame.Image, frame.Layout, date, pending.Token); });
                if (IsDisposed) return;
                if (DateTime.Today != date) report = new Report { Status = OcrStatus.DateChanged };
                diagnostic = "QuickerKeys Trio OCR " + OcrProgram.Version + "\r\nMotor: Tesseract 5.5.0 (pakket lokalt)"
                    + "\r\nDagens filter: " + date.ToString("dd.MM.yyyy") + "\r\nFangst: PrintWindow | layout: UIA-overskrifter og radrektangler"
                    + "\r\nKolonner koblet: " + frame.Layout.Columns.Count + " | synlige radbånd: " + frame.Layout.Rows.Count
                    + "\r\nVarighet inkl. nedtelling (ms): " + elapsed.ElapsedMilliseconds + "\r\n" + report.Summary()
                    + "\r\nIngen bilder, rå celleverdier, ID-er eller bildesignaturer i denne diagnosen.";
                result.Text = diagnostic; report.Observations.Clear();
                status.Text = report.Status == OcrStatus.Read ? "OCR-prøve ferdig. Tallene gjelder bare dette utsnittet." : "Ingen ny OCR-statistikk godkjent: " + report.Status;
            }
            catch (OperationCanceledException) { if (!IsDisposed) { diagnostic = "OCR-prøven ble avbrutt. Ingen nytt resultat godkjent."; result.Text = diagnostic; status.Text = "Avbrutt."; } }
            catch { if (!IsDisposed) { diagnostic = "OCR-prøven feilet. Ingen rå unntak eller bildedata inkludert."; result.Text = diagnostic; status.Text = "Prøven feilet."; } }
            finally { if (frame != null) frame.Clear(); pending.Dispose(); pending = null; if (!IsDisposed) Busy(false); }
        }
        protected override void OnFormClosing(FormClosingEventArgs e) { lifetime.Cancel(); base.OnFormClosing(e); }
    }
}
