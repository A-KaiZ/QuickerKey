// P0 only: window rendering feasibility. No OCR, file output, scrolling or activation.
// Builds with the Windows .NET Framework compiler; no NuGet/runtime downloads.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace QuickerKeys.CaptureProbe
{
    public enum CaptureStatus { Image, TargetChanged, Minimized, SessionUnavailable, InvalidSize,
        NativeFailure, LayoutChanged, Timeout, Cancelled, ProtocolError, InternalError, MetadataUnavailable }

    public sealed class Target
    {
        public IntPtr Window;
        public int ProcessId;
        public long ProcessStartUtc;
    }

    public sealed class CaptureResult
    {
        public CaptureStatus Status;
        public int Width, Height, ErrorCode, Rows = -1, Columns = -1, Dpi;
        public int ClientX, ClientY, ClientWidth, ClientHeight;
        public int FocusStable = -1, SelectionStable = -1, TopStable = -1;
        public long ElapsedMs;
        public byte[] Pixels;
        public bool Varied;

        public void ClearPixels()
        {
            if (Pixels != null) Array.Clear(Pixels, 0, Pixels.Length);
            Pixels = null;
        }

        public Bitmap MakeBitmap()
        {
            if (Status != CaptureStatus.Image || Pixels == null) return null;
            Bitmap image = new Bitmap(Width, Height, PixelFormat.Format32bppRgb);
            BitmapData bits = image.LockBits(new Rectangle(0, 0, Width, Height),
                ImageLockMode.WriteOnly, PixelFormat.Format32bppRgb);
            try
            {
                for (int y = 0; y < Height; y++)
                    Marshal.Copy(Pixels, y * Width * 4, IntPtr.Add(bits.Scan0, y * bits.Stride), Width * 4);
            }
            finally { image.UnlockBits(bits); }
            return image;
        }
    }

    public static class Native
    {
        [StructLayout(LayoutKind.Sequential)] public struct Rect
        {
            public int Left, Top, Right, Bottom;
            public bool Same(Rect other) { return Left == other.Left && Top == other.Top && Right == other.Right && Bottom == other.Bottom; }
        }
        [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
        [StructLayout(LayoutKind.Sequential)] public struct BitmapInfo
        {
            public uint Size; public int Width, Height; public ushort Planes, BitCount;
            public uint Compression, SizeImage; public int XPels, YPels; public uint Used, Important, Color;
        }
        public delegate bool EnumProc(IntPtr window, IntPtr value);
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc proc, IntPtr value);
        [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc proc, IntPtr value);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr window, StringBuilder text, int count);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
        [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out Rect rect);
        [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr window, ref Point point);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
        [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wp, IntPtr lp, uint flags, uint timeout, out IntPtr result);
        [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
        [DllImport("gdi32.dll", SetLastError = true)] public static extern IntPtr CreateDIBSection(IntPtr dc, ref BitmapInfo info, uint usage, out IntPtr pixels, IntPtr section, uint offset);
        [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
        [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
        [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
        [DllImport("gdi32.dll")] public static extern bool GdiFlush();
        [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
        [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
        [DllImport("user32.dll")] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
        [DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr desktop);
        [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint thread);
        [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetUserObjectInformation(IntPtr obj, int index, StringBuilder info, uint length, out uint needed);
        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode)] public static extern bool WTSQuerySessionInformation(IntPtr server, int session, int infoClass, out IntPtr buffer, out int bytes);
        [DllImport("wtsapi32.dll")] public static extern void WTSFreeMemory(IntPtr buffer);

        public static void SetDpiMode()
        {
            try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; }
            catch (EntryPointNotFoundException) { }
            SetProcessDPIAware();
        }
        public static int Dpi(IntPtr window)
        {
            try { return (int)GetDpiForWindow(window); }
            catch (EntryPointNotFoundException) { return 0; }
        }
        public static bool ActiveDesktop()
        {
            IntPtr state = IntPtr.Zero, desktop = IntPtr.Zero;
            try
            {
                int bytes;
                if (!WTSQuerySessionInformation(IntPtr.Zero, -1, 8, out state, out bytes)
                    || bytes < 4 || Marshal.ReadInt32(state) != 0) return false;
                desktop = OpenInputDesktop(0, false, 1); // DESKTOP_READOBJECTS
                if (desktop == IntPtr.Zero) return false;
                StringBuilder input = new StringBuilder(256), current = new StringBuilder(256);
                uint needed;
                return GetUserObjectInformation(desktop, 2, input, 512, out needed)
                    && GetUserObjectInformation(GetThreadDesktop(GetCurrentThreadId()), 2, current, 512, out needed)
                    && String.Equals(input.ToString(), current.ToString(), StringComparison.Ordinal);
            }
            finally
            {
                if (state != IntPtr.Zero) WTSFreeMemory(state);
                if (desktop != IntPtr.Zero) CloseDesktop(desktop);
            }
        }
        public static long Message(IntPtr window, uint message, long wp, long lp)
        {
            IntPtr value;
            return SendMessageTimeout(window, message, new IntPtr(wp), new IntPtr(lp), 3, 150, out value) == IntPtr.Zero
                ? -2 : value.ToInt64();
        }
        public static List<IntPtr> Lists(IntPtr window)
        {
            List<IntPtr> lists = new List<IntPtr>();
            EnumChildWindows(window, delegate(IntPtr child, IntPtr unused)
            {
                StringBuilder name = new StringBuilder(256);
                GetClassName(child, name, name.Capacity);
                if (Regex.IsMatch(name.ToString(), @"^(?:SysListView32|WindowsForms\d*\.SysListView32(?:\.[a-z0-9_]+)*)$", RegexOptions.IgnoreCase)) lists.Add(child);
                return true;
            }, IntPtr.Zero);
            return lists;
        }
    }

    public static class Discovery
    {
        public static bool Validate(Target target, out IntPtr list)
        {
            list = IntPtr.Zero;
            if (target == null || !Native.IsWindow(target.Window) || !Native.IsWindowVisible(target.Window)) return false;
            uint pid;
            Native.GetWindowThreadProcessId(target.Window, out pid);
            if (pid != target.ProcessId || pid == Process.GetCurrentProcess().Id) return false;
            StringBuilder title = new StringBuilder(256);
            Native.GetWindowText(target.Window, title, title.Capacity);
            if (!Regex.IsMatch(title.ToString(), @"^(?:Oppgavelogg|Task\s+(?:Log|History))(?:\s.*)?$", RegexOptions.IgnoreCase)) return false;
            using (Process owner = Process.GetProcessById((int)pid))
            {
                if (!Regex.IsMatch(owner.ProcessName, "trio|attendant", RegexOptions.IgnoreCase)
                    || owner.StartTime.ToUniversalTime().Ticks != target.ProcessStartUtc) return false;
            }
            List<IntPtr> lists = Native.Lists(target.Window);
            if (lists.Count != 1) return false;
            list = lists[0];
            return true;
        }
        public static List<Target> Find()
        {
            List<Target> matches = new List<Target>();
            Native.EnumWindows(delegate(IntPtr window, IntPtr unused)
            {
                try
                {
                    uint pid;
                    Native.GetWindowThreadProcessId(window, out pid);
                    Target candidate;
                    using (Process owner = Process.GetProcessById((int)pid))
                        candidate = new Target { Window = window, ProcessId = (int)pid, ProcessStartUtc = owner.StartTime.ToUniversalTime().Ticks };
                    IntPtr list;
                    if (Validate(candidate, out list)) matches.Add(candidate);
                }
                catch { /* Never export a title, path or provider exception. */ }
                return true;
            }, IntPtr.Zero);
            return matches;
        }
    }

    public sealed class ViewState
    {
        public int Rows, Columns, FirstSelected, SelectedCount, Top;
        public static ViewState Read(IntPtr list)
        {
            long header = Native.Message(list, 0x101F, 0, 0);
            return new ViewState {
                Rows = (int)Native.Message(list, 0x1004, 0, 0),
                Columns = header > 0 ? (int)Native.Message(new IntPtr(header), 0x1200, 0, 0) : -2,
                FirstSelected = (int)Native.Message(list, 0x100C, -1, 2),
                SelectedCount = (int)Native.Message(list, 0x1032, 0, 0),
                Top = (int)Native.Message(list, 0x1027, 0, 0)
            };
        }
    }

    public static class CaptureWorker
    {
        public const int MaxSide = 8192, MaxPixels = 16777216;
        public static CaptureResult Capture(Target target)
        {
            CaptureResult result = new CaptureResult { Status = CaptureStatus.TargetChanged };
            IntPtr list;
            if (!Discovery.Validate(target, out list)) return result;
            if (Native.IsIconic(target.Window)) { result.Status = CaptureStatus.Minimized; return result; }
            if (!Native.ActiveDesktop()) { result.Status = CaptureStatus.SessionUnavailable; return result; }
            Native.Rect before, after;
            if (!Native.GetWindowRect(target.Window, out before)) return result;
            int width = before.Right - before.Left, height = before.Bottom - before.Top;
            if (width < 16 || height < 16 || width > MaxSide || height > MaxSide || (long)width * height > MaxPixels)
            { result.Status = CaptureStatus.InvalidSize; return result; }
            Native.Rect client;
            Native.Point origin = new Native.Point();
            if (!Native.GetClientRect(target.Window, out client) || !Native.ClientToScreen(target.Window, ref origin)) return result;
            int clientX = origin.X - before.Left, clientY = origin.Y - before.Top;
            int clientWidth = client.Right - client.Left, clientHeight = client.Bottom - client.Top;
            if (clientX < 0 || clientY < 0 || clientWidth <= 0 || clientHeight <= 0
                || clientX + clientWidth > width || clientY + clientHeight > height)
            { result.Status = CaptureStatus.InvalidSize; return result; }
            ViewState view = ViewState.Read(list);
            if (!ValidView(view)) { result.Status = CaptureStatus.MetadataUnavailable; return result; }
            IntPtr foreground = Native.GetForegroundWindow();
            IntPtr dc = IntPtr.Zero, dib = IntPtr.Zero, previous = IntPtr.Zero, memory = IntPtr.Zero;
            byte[] pixels = null;
            try
            {
                result.Status = CaptureStatus.NativeFailure;
                dc = Native.CreateCompatibleDC(IntPtr.Zero);
                if (dc == IntPtr.Zero) return result;
                Native.BitmapInfo info = new Native.BitmapInfo { Size = 40, Width = width, Height = -height, Planes = 1, BitCount = 32 };
                dib = Native.CreateDIBSection(dc, ref info, 0, out memory, IntPtr.Zero, 0);
                if (dib == IntPtr.Zero || memory == IntPtr.Zero) { result.ErrorCode = Marshal.GetLastWin32Error(); return result; }
                previous = Native.SelectObject(dc, dib);
                if (previous == IntPtr.Zero || previous == new IntPtr(-1)) return result;
                // Uniform sentinel distinguishes an untouched buffer from an actual varied image.
                pixels = new byte[width * height * 4];
                for (int i = 0; i < pixels.Length; i += 4) { pixels[i] = 37; pixels[i + 1] = 23; pixels[i + 2] = 11; }
                Marshal.Copy(pixels, 0, memory, pixels.Length);
                Stopwatch timer = Stopwatch.StartNew();
                bool rendered = Native.PrintWindow(target.Window, dc, 0); // Whole target window; no desktop fallback.
                timer.Stop(); result.ElapsedMs = timer.ElapsedMilliseconds;
                Native.GdiFlush();
                if (!rendered) return result; // PrintWindow does not document a useful GetLastError contract.
                Marshal.Copy(memory, pixels, 0, pixels.Length);
                IntPtr currentList;
                if (!Discovery.Validate(target, out currentList) || currentList != list)
                { result.Status = CaptureStatus.TargetChanged; return result; }
                if (!Native.ActiveDesktop()) { result.Status = CaptureStatus.SessionUnavailable; return result; }
                if (Native.IsIconic(target.Window)) { result.Status = CaptureStatus.Minimized; return result; }
                ViewState current = ViewState.Read(list);
                if (!ValidView(current)) { result.Status = CaptureStatus.MetadataUnavailable; return result; }
                result.FocusStable = foreground == IntPtr.Zero ? -1 : (foreground == Native.GetForegroundWindow() ? 1 : 0);
                result.SelectionStable = view.SelectedCount < 0 || current.SelectedCount < 0 || view.FirstSelected < -1 || current.FirstSelected < -1
                    ? -1 : (view.SelectedCount == current.SelectedCount && view.FirstSelected == current.FirstSelected ? 1 : 0);
                result.TopStable = view.Top < 0 || current.Top < 0 ? -1 : (view.Top == current.Top ? 1 : 0);
                if (!Native.GetWindowRect(target.Window, out after) || !before.Same(after)
                    || view.Rows != current.Rows || view.Columns != current.Columns || result.TopStable == 0)
                { result.Status = CaptureStatus.LayoutChanged; return result; }
                result.Width = width; result.Height = height; result.Dpi = Native.Dpi(target.Window);
                result.ClientX = clientX; result.ClientY = clientY; result.ClientWidth = clientWidth; result.ClientHeight = clientHeight;
                result.Rows = current.Rows; result.Columns = current.Columns;
                result.Pixels = pixels; pixels = null;
                result.Varied = HasVariation(result);
                result.Status = CaptureStatus.Image;
                return result;
            }
            finally
            {
                if (pixels != null) Array.Clear(pixels, 0, pixels.Length);
                if (previous != IntPtr.Zero && previous != new IntPtr(-1)) Native.SelectObject(dc, previous);
                if (dib != IntPtr.Zero) Native.DeleteObject(dib);
                if (dc != IntPtr.Zero) Native.DeleteDC(dc);
            }
        }
        private static bool ValidView(ViewState view)
        {
            return view.Rows >= 0 && view.Columns > 0 && view.FirstSelected >= -1 && view.SelectedCount >= 0 && view.Top >= 0;
        }
        public static bool HasVariation(CaptureResult image)
        {
            HashSet<int> colors = new HashSet<int>();
            byte[] pixels = image.Pixels;
            for (int y = image.ClientY; y < image.ClientY + image.ClientHeight; y++)
            {
                for (int x = image.ClientX; x < image.ClientX + image.ClientWidth; x++)
                {
                    int i = (y * image.Width + x) * 4;
                    colors.Add((pixels[i] >> 4) | ((pixels[i + 1] >> 4) << 4) | ((pixels[i + 2] >> 4) << 8));
                    if (colors.Count >= 4) return true;
                }
            }
            return false;
        }
        public static void Write(Stream output, CaptureResult result)
        {
            using (BinaryWriter writer = new BinaryWriter(output))
            {
                writer.Write(0x50434B51); writer.Write(2); writer.Write((int)result.Status);
                writer.Write(result.Width); writer.Write(result.Height); writer.Write(result.ErrorCode);
                writer.Write(result.Rows); writer.Write(result.Columns); writer.Write(result.Dpi);
                writer.Write(result.ClientX); writer.Write(result.ClientY); writer.Write(result.ClientWidth); writer.Write(result.ClientHeight);
                writer.Write(result.FocusStable); writer.Write(result.SelectionStable); writer.Write(result.TopStable);
                writer.Write(result.ElapsedMs);
                writer.Write(result.Pixels == null ? 0 : result.Pixels.Length);
                if (result.Pixels != null) writer.Write(result.Pixels);
            }
        }
        public static CaptureResult Read(Stream input)
        {
            using (BinaryReader reader = new BinaryReader(input))
            {
                if (reader.ReadInt32() != 0x50434B51 || reader.ReadInt32() != 2) throw new InvalidDataException();
                int status = reader.ReadInt32();
                if (!Enum.IsDefined(typeof(CaptureStatus), status)) throw new InvalidDataException();
                CaptureResult result = new CaptureResult { Status = (CaptureStatus)status,
                    Width = reader.ReadInt32(), Height = reader.ReadInt32(), ErrorCode = reader.ReadInt32(),
                    Rows = reader.ReadInt32(), Columns = reader.ReadInt32(), Dpi = reader.ReadInt32(),
                    ClientX = reader.ReadInt32(), ClientY = reader.ReadInt32(), ClientWidth = reader.ReadInt32(), ClientHeight = reader.ReadInt32(),
                    FocusStable = reader.ReadInt32(), SelectionStable = reader.ReadInt32(), TopStable = reader.ReadInt32(),
                    ElapsedMs = reader.ReadInt64() };
                int length = reader.ReadInt32();
                if (result.Status == CaptureStatus.Image)
                {
                    if (result.Width < 16 || result.Height < 16 || result.Width > MaxSide || result.Height > MaxSide
                        || (long)result.Width * result.Height > MaxPixels || length != (long)result.Width * result.Height * 4
                        || result.ClientX < 0 || result.ClientY < 0 || result.ClientWidth <= 0 || result.ClientHeight <= 0
                        || (long)result.ClientX + result.ClientWidth > result.Width || (long)result.ClientY + result.ClientHeight > result.Height)
                        throw new InvalidDataException();
                    result.Pixels = reader.ReadBytes(length);
                    if (result.Pixels.Length != length) { result.ClearPixels(); throw new InvalidDataException(); }
                    result.Varied = HasVariation(result);
                }
                else if (length != 0) throw new InvalidDataException();
                if (reader.Read() != -1) { result.ClearPixels(); throw new InvalidDataException(); }
                return result;
            }
        }
    }

    public static class CaptureClient
    {
        public static async Task<CaptureResult> Run(string executable, Target target, int timeoutMs, CancellationToken cancellation)
        {
            Stopwatch elapsed = Stopwatch.StartNew();
            ProcessStartInfo start = new ProcessStartInfo(executable,
                "--worker " + target.Window.ToInt64().ToString(CultureInfo.InvariantCulture) + " "
                + target.ProcessId.ToString(CultureInfo.InvariantCulture) + " " + target.ProcessStartUtc.ToString(CultureInfo.InvariantCulture));
            start.UseShellExecute = false; start.CreateNoWindow = true;
            start.RedirectStandardOutput = true; start.RedirectStandardError = true;
            using (Process worker = new Process { StartInfo = start })
            {
                Task<CaptureResult> reading = null;
                bool accepted = false;
                try
                {
                    if (cancellation.IsCancellationRequested) return new CaptureResult { Status = CaptureStatus.Cancelled };
                    worker.Start();
                    reading = Task.Run(delegate { return CaptureWorker.Read(worker.StandardOutput.BaseStream); });
                    Task finished = await Task.WhenAny(reading, Task.Delay(timeoutMs, cancellation)).ConfigureAwait(false);
                    if (finished != reading)
                        return new CaptureResult { Status = cancellation.IsCancellationRequested ? CaptureStatus.Cancelled : CaptureStatus.Timeout, ElapsedMs = elapsed.ElapsedMilliseconds };
                    CaptureResult result = await reading.ConfigureAwait(false);
                    if (cancellation.IsCancellationRequested) { result.ClearPixels(); return new CaptureResult { Status = CaptureStatus.Cancelled }; }
                    accepted = true;
                    return result;
                }
                catch { return new CaptureResult { Status = CaptureStatus.ProtocolError, ElapsedMs = elapsed.ElapsedMilliseconds }; }
                finally
                {
                    try { if (!worker.HasExited) worker.Kill(); worker.WaitForExit(500); } catch { }
                    // Closing the pipe/worker releases a blocked reader. Observe and clear any late result.
                    if (reading != null) ObserveLateResult(reading, accepted);
                }
            }
        }
        private static void ObserveLateResult(Task<CaptureResult> reading, bool accepted)
        {
            reading.ContinueWith(delegate(Task<CaptureResult> task) {
                if (task.Status == TaskStatus.RanToCompletion && !accepted) task.Result.ClearPixels();
                if (task.IsFaulted) { var ignored = task.Exception; }
            }, TaskScheduler.Default);
        }
    }

    public static class Program
    {
        public const string Version = "P0.1";
        [STAThread] public static int Main(string[] args)
        {
            Native.SetDpiMode();
            if (args.Length != 0)
            {
                if (args.Length != 4 || args[0] != "--worker") return 2;
                new Thread(delegate() { Thread.Sleep(5000); Environment.Exit(3); }) { IsBackground = true }.Start();
                CaptureResult result;
                try
                {
                    long handle = Int64.Parse(args[1], CultureInfo.InvariantCulture);
                    int pid = Int32.Parse(args[2], CultureInfo.InvariantCulture);
                    long created = Int64.Parse(args[3], CultureInfo.InvariantCulture);
                    result = CaptureWorker.Capture(new Target { Window = new IntPtr(handle), ProcessId = pid, ProcessStartUtc = created });
                }
                catch { result = new CaptureResult { Status = CaptureStatus.InternalError }; }
                try { CaptureWorker.Write(Console.OpenStandardOutput(), result); }
                catch { return 2; }
                finally { result.ClearPixels(); }
                return 0;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new ProbeForm());
            return 0;
        }
    }

    public sealed class ProbeForm : Form
    {
        private Target target;
        private readonly CancellationTokenSource lifetime = new CancellationTokenSource();
        private CancellationTokenSource pending;
        private readonly Label status = new Label(), instructions = new Label();
        private readonly PictureBox preview = new PictureBox();
        private readonly CheckBox readable = new CheckBox();
        private readonly CheckBox fresh = new CheckBox();
        private readonly List<Button> actions = new List<Button>();
        private readonly Dictionary<int, string> reports = new Dictionary<int, string>();
        private string lastSummary = "", previousHash = "";
        private int lastStage = -1;
        private bool busy;

        public ProbeForm()
        {
            Text = "QuickerKeys – vindusfangst " + Program.Version;
            ClientSize = new Size(1050, 780); MinimumSize = new Size(860, 560);
            Font = new Font("Segoe UI", 10); StartPosition = FormStartPosition.CenterScreen;
            TableLayoutPanel layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(12) };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 48));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
            instructions.Dock = DockStyle.Fill;
            instructions.Text = "P0 undersøker bare bildehenting. Åpne Trio Oppgavelogg uten minimering.\r\nBildet vises lokalt i RAM. Ingen bilder eller celleverdier lagres eller kopieres til diagnose.";
            layout.Controls.Add(instructions, 0, 0);
            FlowLayoutPanel buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = true };
            Button find = AddButton(buttons, "Finn Oppgavelogg"); find.Click += async delegate { await FindTarget(); };
            string[] stages = { "1 · Synlig logg (5 s)", "2 · Dekket logg (5 s)", "3 · Etter ny oppgave (5 s)" };
            for (int i = 0; i < stages.Length; i++)
            {
                int stage = i;
                Button capture = AddButton(buttons, stages[i]); capture.Click += async delegate { await RunCapture(stage); };
            }
            Button copy = AddButton(buttons, "Kopier anonym diagnose"); copy.Click += delegate { CopyReport(); };
            Button cancel = new Button { Text = "Avbryt", AutoSize = true };
            cancel.Click += delegate { if (pending != null) pending.Cancel(); }; buttons.Controls.Add(cancel);
            layout.Controls.Add(buttons, 0, 1);
            status.Dock = DockStyle.Fill; status.Text = "Trykk Finn Oppgavelogg. Ingen automatisk innlesing er startet.";
            layout.Controls.Add(status, 0, 2);
            Panel scroll = new Panel { Dock = DockStyle.Fill, AutoScroll = true, BorderStyle = BorderStyle.FixedSingle, BackColor = Color.WhiteSmoke };
            preview.SizeMode = PictureBoxSizeMode.AutoSize; scroll.Controls.Add(preview); layout.Controls.Add(scroll, 0, 3);
            readable.Text = "Jeg har kontrollert at tabellteksten i dette bildet er lesbar"; readable.AutoSize = true; readable.Enabled = false;
            fresh.Text = "Prøve 3: Jeg ser den nye oppgaven i dette bildet"; fresh.AutoSize = true; fresh.Enabled = false;
            readable.CheckedChanged += delegate { UpdateConfirmation(); };
            fresh.CheckedChanged += delegate { UpdateConfirmation(); };
            FlowLayoutPanel confirmations = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown };
            confirmations.Controls.Add(readable); confirmations.Controls.Add(fresh);
            layout.Controls.Add(confirmations, 0, 4); Controls.Add(layout);
        }
        private Button AddButton(Control parent, string text)
        {
            Button button = new Button { Text = text, AutoSize = true, Margin = new Padding(0, 0, 8, 6) };
            actions.Add(button); parent.Controls.Add(button); return button;
        }
        private void SetBusy(bool value)
        {
            busy = value; foreach (Button button in actions) button.Enabled = !value;
            readable.Enabled = !value && preview.Image != null;
            fresh.Enabled = !value && preview.Image != null && lastStage == 2;
        }
        private async Task FindTarget()
        {
            if (busy) return;
            SetBusy(true); status.Text = "Finner en entydig Trio Oppgavelogg…";
            try
            {
                List<Target> found = await Task.Run(delegate { return Discovery.Find(); });
                if (IsDisposed) return;
                target = found.Count == 1 ? found[0] : null;
                reports.Clear(); previousHash = ""; lastStage = -1; ClearPreview();
                status.Text = found.Count == 1 ? "Oppgavelogg funnet. Første prøve: la loggen være synlig når nedtellingen er ferdig."
                    : "Fant " + found.Count + " passende loggvinduer. Trenger nøyaktig ett fra Trio med én ListView.";
            }
            catch { if (!IsDisposed) status.Text = "Kunne ikke undersøke vinduene. Ingen fangst utført."; }
            finally { if (!IsDisposed) SetBusy(false); }
        }
        private async Task RunCapture(int stage)
        {
            if (busy) return;
            if (target == null) { status.Text = "Finn Oppgavelogg først."; return; }
            SetBusy(true); lastStage = -1; ClearPreview();
            reports.Remove(stage);
            pending = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
            CaptureResult result = null;
            try
            {
                for (int seconds = 5; seconds > 0; seconds--)
                {
                    status.Text = "Prøve " + (stage + 1) + " om " + seconds + " s. "
                        + (stage == 0 ? "La tabellinnholdet være synlig." : "Dekk Oppgavelogg med et annet vindu; ikke minimer den.");
                    await Task.Delay(1000, pending.Token);
                }
                result = await CaptureClient.Run(Application.ExecutablePath, target, 3500, pending.Token);
                if (IsDisposed) return;
                string sameImage = "ikke sammenlignet";
                if (result.Status == CaptureStatus.Image)
                {
                    string hash;
                    using (SHA256 sha = SHA256.Create()) hash = Convert.ToBase64String(sha.ComputeHash(result.Pixels));
                    if (previousHash != "") sameImage = previousHash == hash ? "likt forrige bilde (ferskhet uavklart)" : "endret siden forrige bilde";
                    previousHash = hash;
                }
                ClearPreview();
                if (result.Status == CaptureStatus.Image) preview.Image = result.MakeBitmap();
                lastStage = stage;
                lastSummary = "Prøve: " + (stage + 1) + "\r\nUtført lokalt: " + DateTime.Now.ToString("dd.MM.yyyy HH:mm:ss")
                    + "\r\nUtfall: " + result.Status + "\r\nBilde: " + result.Width + " × " + result.Height + " | DPI: " + result.Dpi
                    + "\r\nRader: " + result.Rows + " | kolonner: " + result.Columns
                    + "\r\nPrintWindow-tid (ms): " + result.ElapsedMs + " | feilnummer: " + result.ErrorCode
                    + "\r\nBildevariasjon i klientområdet: " + (result.Varied ? "ja (beviser ikke lesbar tekst)" : "nei/ikke målt")
                    + "\r\nForgrunnsvindu uendret: " + Stable(result.FocusStable)
                    + "\r\nAntall og første valgte rad uendret: " + Stable(result.SelectionStable)
                    + "\r\nØverste rad uendret: " + Stable(result.TopStable) + "\r\nBildeendring: " + sameImage;
                reports[stage] = lastSummary + "\r\nLesbarhet manuelt bekreftet: nei";
                UpdateConfirmation();
                status.Text = result.Status == CaptureStatus.Image
                    ? "Bilde mottatt. Kontroller tabellteksten i forhåndsvisningen og marker lesbarhet nederst."
                    : "Ingen godkjent bildefangst: " + result.Status + ". Tidligere bilde er fjernet.";
            }
            catch (OperationCanceledException)
            {
                reports[stage] = "Prøve: " + (stage + 1) + "\r\nUtfall: Cancelled\r\nIngen ny bildefangst godkjent.";
                if (!IsDisposed) status.Text = "Prøven ble avbrutt.";
            }
            catch
            {
                reports[stage] = "Prøve: " + (stage + 1) + "\r\nUtfall: InternalError\r\nIngen ny bildefangst godkjent.";
                if (!IsDisposed) { lastStage = -1; ClearPreview(); status.Text = "Prøven feilet. Ingen rå feiltekst eller bilde er lagret."; }
            }
            finally
            {
                if (result != null) result.ClearPixels();
                pending.Dispose(); pending = null;
                if (!IsDisposed) SetBusy(false);
            }
        }
        private static string Stable(int value) { return value < 0 ? "ukjent" : value == 1 ? "ja" : "nei/endret under prøven"; }
        private void UpdateConfirmation()
        {
            if (lastStage >= 0) reports[lastStage] = lastSummary
                + "\r\nLesbarhet manuelt bekreftet: " + (readable.Checked ? "ja" : "nei")
                + (lastStage == 2 ? "\r\nNy oppgave manuelt bekreftet i bildet: " + (fresh.Checked ? "ja" : "nei") : "");
        }
        private void CopyReport()
        {
            StringBuilder report = new StringBuilder("QuickerKeys Trio vindusfangst " + Program.Version
                + "\r\nMetode: PrintWindow (hele mål-vinduet)\r\nWorker: " + (IntPtr.Size * 8) + "-bit\r\n");
            for (int i = 0; i < 3; i++) if (reports.ContainsKey(i)) report.Append("\r\n").Append(reports[i]).Append("\r\n");
            report.Append("\r\nPrøvetype/dekking er valgt av brukeren, ikke automatisk verifisert.\r\nIngen bilder, rå celleverdier, vindustitler, prosessnavn eller bildesignaturer inkludert.\r\nEndret bilde beviser ikke at nye oppgaver er lest. P0 har ingen OCR eller statistikkimport.");
            try { Clipboard.SetText(report.ToString()); status.Text = "Anonym diagnose kopiert."; }
            catch { status.Text = "Utklippstavlen var ikke tilgjengelig. Prøv igjen."; }
        }
        private void ClearPreview()
        {
            Image old = preview.Image; preview.Image = null;
            if (old != null) old.Dispose();
            readable.Checked = false; readable.Enabled = false;
            fresh.Checked = false; fresh.Enabled = false;
        }
        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            lifetime.Cancel(); lastStage = -1; ClearPreview(); base.OnFormClosing(e);
        }
    }
}
