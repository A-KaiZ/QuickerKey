using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using QuickerKeys.CaptureProbe;

public static class CaptureTests
{
    private static string probe;
    private static int checks;
    private static void Require(bool condition, string label)
    {
        if (!condition) throw new Exception(label);
        checks++; Console.WriteLine("PASS " + label);
    }
    private static CaptureResult Capture(Target target, int timeout)
    { return CaptureClient.Run(probe, target, timeout, CancellationToken.None).GetAwaiter().GetResult(); }
    private static void WithFixture(string path, string mode, Action<Process, Target> test)
    {
        using (Process fixture = Process.Start(new ProcessStartInfo(path, mode) { UseShellExecute = false }))
        {
            try
            {
                Target target = null;
                Stopwatch timer = Stopwatch.StartNew();
                while (timer.ElapsedMilliseconds < 15000)
                {
                    fixture.Refresh();
                    if (fixture.HasExited) throw new Exception("fixture exited");
                    if (fixture.MainWindowHandle != IntPtr.Zero)
                    {
                        Target candidate = new Target { Window = fixture.MainWindowHandle, ProcessId = fixture.Id, ProcessStartUtc = fixture.StartTime.ToUniversalTime().Ticks };
                        IntPtr list;
                        if (Discovery.Validate(candidate, out list)) {
                            ViewState ready = ViewState.Read(list);
                            if (ready.Rows == 8 && ready.Columns == 13 && ready.SelectedCount == 1 && ready.FirstSelected == 2) { target = candidate; break; }
                        }
                    }
                    Thread.Sleep(40);
                }
                if (target == null) throw new Exception("fixture not ready");
                Thread.Sleep(150); test(fixture, target);
            }
            finally { if (!fixture.HasExited) { fixture.Kill(); fixture.WaitForExit(1000); } }
        }
    }
    private static bool HasColor(CaptureResult result, Color color)
    {
        int count = 0;
        for (int i = 0; i < result.Pixels.Length; i += 4)
            if (result.Pixels[i] == color.B && result.Pixels[i + 1] == color.G && result.Pixels[i + 2] == color.R) count++;
        return count >= 500;
    }
    private static void Reject(Action read, string label)
    {
        bool rejected = false;
        try { read(); } catch (InvalidDataException) { rejected = true; } catch (EndOfStreamException) { rejected = true; }
        Require(rejected, label);
    }
    private static bool PreviewMatches(CaptureResult result)
    {
        using (Bitmap preview = result.MakeBitmap())
        {
            for (int i = 0; i < result.Pixels.Length; i += 4)
                if (result.Pixels[i] == 0 && result.Pixels[i + 1] == 255 && result.Pixels[i + 2] == 0)
                    return preview.GetPixel((i / 4) % result.Width, (i / 4) / result.Width).ToArgb() == Color.Lime.ToArgb();
            return false;
        }
    }
    [STAThread] public static int Main(string[] args)
    {
        try
        {
            Native.SetDpiMode(); probe = Path.GetFullPath(args[0]);
            string stalledWorker = Path.GetFullPath(args[1]);
            Require(Native.ActiveDesktop(), "test runner has an active accessible desktop");
            foreach (string fixture in args.Skip(2))
            {
                Console.WriteLine("TARGET " + Path.GetFileName(fixture));
                WithFixture(fixture, "paint", delegate(Process owner, Target target)
                {
                    Require(Discovery.Find().Any(t => t.Window == target.Window), "discovery finds the separate-process ListView target");
                    CaptureResult visible = Capture(target, 3500);
                    Require(visible.Status == CaptureStatus.Image && visible.Varied && HasColor(visible, Color.Lime) && HasColor(visible, Color.Blue), "visible capture contains private painted content (status=" + visible.Status + ", varied=" + visible.Varied + ", rows=" + visible.Rows + ", cols=" + visible.Columns + ")");
                    Require(visible.Rows == 8 && visible.Columns == 13, "native metadata is retained");
                    Require(PreviewMatches(visible), "user preview preserves captured pixel color and position"); visible.ClearPixels();
                    Native.Rect rect; Native.GetWindowRect(target.Window, out rect);
                    using (Form cover = new Form { Text = "Synthetic covering window", StartPosition = FormStartPosition.Manual,
                        Location = new Point(rect.Left - 20, rect.Top - 20), Size = new Size(rect.Right - rect.Left + 40, rect.Bottom - rect.Top + 40), BackColor = Color.Magenta })
                    {
                        cover.Show(); cover.Activate(); Application.DoEvents(); Thread.Sleep(100);
                        IntPtr foreground = Native.GetForegroundWindow();
                        Require(foreground == cover.Handle, "cover is the foreground window before capture");
                        CaptureResult covered = Capture(target, 3500);
                        Require(covered.Status == CaptureStatus.Image && HasColor(covered, Color.Blue) && !HasColor(covered, Color.Magenta), "covered capture renders the target rather than desktop pixels");
                        Require(covered.FocusStable == 1 && covered.SelectionStable == 1 && covered.TopStable == 1
                            && Native.GetForegroundWindow() == foreground, "worker preserves foreground selection and scroll position"); covered.ClearPixels();
                        Require(Native.Message(target.Window, 0x8015, 0, 0) == 1, "synthetic target changed behind cover");
                        CaptureResult changed = Capture(target, 3500);
                        Require(changed.Status == CaptureStatus.Image && HasColor(changed, Color.Red) && !HasColor(changed, Color.Blue), "a new covered capture reflects changed target content"); changed.ClearPixels();
                    }
                    Target wrong = new Target { Window = target.Window, ProcessId = target.ProcessId + 1, ProcessStartUtc = target.ProcessStartUtc };
                    Require(Capture(wrong, 3500).Status == CaptureStatus.TargetChanged, "wrong process identity is rejected");
                    wrong.ProcessId = target.ProcessId; wrong.ProcessStartUtc++;
                    Require(Capture(wrong, 3500).Status == CaptureStatus.TargetChanged, "process generation mismatch is rejected");
                    ShowWindow(target.Window, 6); Thread.Sleep(150);
                    Require(Capture(target, 3500).Status == CaptureStatus.Minimized && Native.IsIconic(target.Window), "minimized target is skipped and not restored");
                    owner.Kill(); owner.WaitForExit(1000);
                    Require(Capture(target, 3500).Status == CaptureStatus.TargetChanged, "closed target produces no stale image");
                });
                WithFixture(fixture, "native", delegate(Process owner, Target target)
                {
                    CaptureResult image = Capture(target, 3500);
                    Require(image.Status == CaptureStatus.Image && image.Varied && image.Rows == 8 && image.Columns == 13,
                        "normal native ListView target produces a varied image"); image.ClearPixels();
                });
                WithFixture(fixture, "blank", delegate(Process owner, Target target)
                {
                    CaptureResult blank = Capture(target, 3500);
                    Require(blank.Status == CaptureStatus.Image && !blank.Varied, "successful blank client rendering is not classified as varied content (status=" + blank.Status + ", varied=" + blank.Varied
                        + ", client=" + blank.ClientX + "," + blank.ClientY + "," + blank.ClientWidth + "," + blank.ClientHeight + ")"); blank.ClearPixels();
                });
                WithFixture(fixture, "paint", delegate(Process owner, Target target)
                {
                    Require(PostMessage(target.Window, 0x8016, IntPtr.Zero, IntPtr.Zero), "synthetic target UI thread is stalled");
                    Thread.Sleep(100);
                    CaptureResult blocked = Capture(target, 3500);
                    Require(blocked.Status == CaptureStatus.MetadataUnavailable && blocked.Pixels == null,
                        "unresponsive native metadata cannot yield a newly accepted image (status=" + blocked.Status + ")");
                });
                WithFixture(fixture, "paint", delegate(Process owner, Target target)
                {
                    Stopwatch elapsed = Stopwatch.StartNew();
                    CaptureResult timeout = CaptureClient.Run(stalledWorker, target, 600, CancellationToken.None).GetAwaiter().GetResult();
                    Require(timeout.Status == CaptureStatus.Timeout && elapsed.ElapsedMilliseconds < 2500, "stalled worker is bounded in the parent");
                    using (CancellationTokenSource cancellation = new CancellationTokenSource())
                    {
                        cancellation.CancelAfter(600);
                        CaptureResult cancelled = CaptureClient.Run(stalledWorker, target, 3500, cancellation.Token).GetAwaiter().GetResult();
                        Require(cancelled.Status == CaptureStatus.Cancelled, "cancellation stops a pending capture");
                    }
                });
            }
            Reject(delegate { CaptureWorker.Read(new MemoryStream(new byte[64])); }, "invalid protocol header is rejected");
            byte[] malformed;
            using (MemoryStream memory = new MemoryStream())
            {
                CaptureWorker.Write(memory, new CaptureResult { Status = CaptureStatus.Image, Width = Int32.MaxValue, Height = 100 });
                malformed = memory.ToArray();
            }
            Reject(delegate { CaptureWorker.Read(new MemoryStream(malformed)); }, "oversized frame is rejected before allocation");
            using (MemoryStream memory = new MemoryStream())
            {
                CaptureWorker.Write(memory, new CaptureResult { Status = CaptureStatus.Image, Width = 16, Height = 16, ClientWidth = 16, ClientHeight = 16, Pixels = new byte[1024] });
                byte[] complete = memory.ToArray();
                malformed = complete.Take(complete.Length - 1).ToArray();
            }
            Reject(delegate { CaptureWorker.Read(new MemoryStream(malformed)); }, "truncated frame is rejected");
            Require(Process.GetProcessesByName(Path.GetFileNameWithoutExtension(probe)).Length == 0, "no worker process remains after captures timeouts and cancellation");
            Require(Process.GetProcessesByName(Path.GetFileNameWithoutExtension(stalledWorker)).Length == 0, "no stalled worker process remains");
            Console.WriteLine("PASS total=" + checks); return 0;
        }
        catch (Exception error) { Console.WriteLine("FAIL " + error.GetType().Name + ": " + error.Message); return 1; }
    }
    [System.Runtime.InteropServices.DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr window, int command);
    [System.Runtime.InteropServices.DllImport("user32.dll")] private static extern bool PostMessage(IntPtr window, uint message, IntPtr wp, IntPtr lp);
}
