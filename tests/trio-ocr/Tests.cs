using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using QuickerKeys.CaptureProbe;
using QuickerKeys.Ocr;

public static class OcrTests
{
    private static int checks;
    private static readonly DateTime Day = new DateTime(2026, 11, 4);
    private static void Require(bool value, string label) { if (!value) throw new Exception(label); checks++; Console.WriteLine("PASS " + label); }
    private static Layout MakeLayout(int rows, double scale, bool moved)
    {
        int x = 10, top = 30, height = (int)Math.Round(24 * scale);
        Field[] order = moved ? new[] { Field.Queue, Field.Time, Field.Handling, Field.TaskId } : new[] { Field.Time, Field.TaskId, Field.Handling, Field.Queue };
        Layout layout = new Layout();
        foreach (Field key in order)
        {
            int width = (int)Math.Round((key == Field.Time ? 185 : key == Field.TaskId ? 130 : 90) * scale);
            layout.Columns.Add(key, new Rectangle(x, top, width, rows * height)); x += width;
        }
        layout.Body = new Rectangle(10, top, x - 10, rows * height);
        for (int i = 0; i < rows; i++) layout.Rows.Add(new Rectangle(10, top + i * height, x - 10, height));
        return layout;
    }
    private static Dictionary<Field, Cell[]> Data(Layout layout)
    {
        Dictionary<Field, Cell[]> data = new Dictionary<Field, Cell[]>();
        foreach (Field field in layout.Columns.Keys) data[field] = layout.Rows.Select(r => new Cell { Confidence = 95 }).ToArray();
        for (int i = 0; i < layout.Rows.Count; i++)
        {
            data[Field.Time][i].Text = Day.ToString("dd.MM.yyyy") + " 09:10:11";
            data[Field.TaskId][i].Text = (123456781 + i).ToString();
            data[Field.Handling][i].Text = "02:30"; data[Field.Queue][i].Text = "00:10";
        }
        return data;
    }
    private static void UnitTests()
    {
        Layout layout = MakeLayout(2, 1, false); var data = Data(layout);
        Require(layout.Valid(700, 200), "valid geometry is accepted");
        Require(Validator.Evaluate(layout, data, Day).Observations.Count == 2, "different IDs with the same timestamp are distinct tasks");
        data[Field.TaskId][0].Text = "";
        Require(Validator.Evaluate(layout, data, Day).Observations.Single().Id == data[Field.TaskId][1].Text, "missing identity never borrows the next row's ID");
        data = Data(layout); data[Field.Time][0].Text = "31.02.2026 09:10:11";
        Require(Validator.Evaluate(layout, data, Day).InvalidDate == 1, "invalid calendar date is rejected");
        data[Field.Time][0].Text = "04.11.2026 09:10";
        Require(Validator.Evaluate(layout, data, Day).InvalidDate == 1, "missing timestamp seconds are not fabricated");
        data = Data(layout); data[Field.TaskId][0].Text = "12345678O";
        Require(Validator.Evaluate(layout, data, Day).InvalidId == 1, "letters are not silently converted into ID digits");
        data[Field.TaskId][0].Text = "123456781"; data[Field.TaskId][0].Confidence = 20;
        Require(Validator.Evaluate(layout, data, Day).LowConfidence == 1, "low confidence identity stays rejected");
        data = Data(layout); data[Field.Handling][0].Text = ""; data[Field.Queue][0].Text = "00:00";
        Observation known = Validator.Evaluate(layout, data, Day).Observations.First(o => o.Id == "123456781");
        Require(!known.HandlingSeconds.HasValue && known.QueueSeconds == 0, "missing duration and actual zero are distinct");
        data = Data(layout); data[Field.Time][0].Text = "03.11.2026 09:10:11"; data[Field.TaskId][0].Text = "not an ID";
        Report historic = Validator.Evaluate(layout, data, Day);
        Require(historic.OtherDays == 1 && historic.InvalidId == 0, "historical rows are discarded before identity parsing");
        data = Data(layout); data[Field.TaskId][1].Text = data[Field.TaskId][0].Text;
        Require(Validator.Evaluate(layout, data, Day).Observations.Count == 1, "identical duplicate rows are counted once");
        data[Field.Queue][1].Text = "00:11";
        Report conflict = Validator.Evaluate(layout, data, Day);
        Require(conflict.Observations.Count == 0 && conflict.Conflicts == 1, "contradictory duplicates are quarantined");
        Rectangle column = layout.Columns[Field.Time];
        Word crossing = new Word { Text = "04.11.2026 09:10:11", Confidence = 99, Bounds = new RectangleF(column.X + 2, layout.Rows[0].Bottom - 2, 120, 6) };
        Require(Validator.Cells(layout, Field.Time, new[] { crossing }).All(c => c.Conflict), "text crossing a row boundary conflicts with both rows");
        var outside = new Word { Text = "123456781", Confidence = 99, Bounds = new RectangleF(layout.Columns[Field.TaskId].X - 2, layout.Rows[0].Top + 3, 60, 12) };
        Require(Validator.Cells(layout, Field.TaskId, new[] { outside })[0].Conflict, "text crossing a column boundary is rejected");
        Layout overlapping = MakeLayout(2, 1, false); overlapping.Rows[1] = overlapping.Rows[0];
        Require(!overlapping.Valid(700, 200), "overlapping row geometry is rejected");
        string summary = Validator.Evaluate(layout, Data(layout), Day).Summary();
        Require(!summary.Contains("123456781") && !summary.Contains("09:10:11"), "diagnostics contain no raw identities or timestamps");
        DateTime parsed;
        Require(Validator.Timestamp("04.11.2026 09:10:11", out parsed) && parsed.Date == Day, "strict timestamp retains the full date");
    }
    private static Frame Render(double scale, bool moved)
    {
        Layout layout = MakeLayout(5, scale, moved);
        using (Bitmap bitmap = new Bitmap(layout.Body.Right + 10, layout.Body.Bottom + 10, PixelFormat.Format32bppRgb))
        {
            using (Graphics graphics = Graphics.FromImage(bitmap)) using (Font font = new Font("Tahoma", (float)(10 * scale)))
            {
                graphics.Clear(Color.White); graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                for (int i = 0; i < 5; i++)
                {
                    Rectangle row = layout.Rows[i];
                    graphics.FillRectangle(i == 1 ? Brushes.RoyalBlue : i % 2 == 0 ? Brushes.White : Brushes.WhiteSmoke, row);
                    foreach (var column in layout.Columns)
                    {
                        string text = column.Key == Field.Time ? (i == 4 ? Day.AddDays(-1) : Day).ToString("dd.MM.yyyy") + " 09:10:1" + i
                            : column.Key == Field.TaskId ? (123456781 + i).ToString() : column.Key == Field.Handling ? "02:30" : "00:10";
                        Brush ink = i == 1 ? Brushes.White : i == 2 ? Brushes.Red : Brushes.Black;
                        graphics.DrawString(text, font, ink, column.Value.X + 5, row.Y + 3);
                    }
                }
            }
            BitmapData bits = bitmap.LockBits(new Rectangle(0, 0, bitmap.Width, bitmap.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppRgb);
            byte[] pixels = new byte[bitmap.Width * bitmap.Height * 4];
            try { for (int y = 0; y < bitmap.Height; y++) Marshal.Copy(IntPtr.Add(bits.Scan0, y * bits.Stride), pixels, y * bitmap.Width * 4, bitmap.Width * 4); }
            finally { bitmap.UnlockBits(bits); }
            return new Frame { Layout = layout, Image = new CaptureResult { Status = CaptureStatus.Image, Width = bitmap.Width, Height = bitmap.Height, Pixels = pixels } };
        }
    }
    private static void GoldenTests(Engine engine)
    {
        Reader reader = new Reader(engine);
        foreach (double scale in new[] { 1.0, 1.25, 1.5, 2.0 })
        {
            Frame frame = Render(scale, scale != 1.0);
            try
            {
                Report report = reader.Read(frame.Image, frame.Layout, Day, CancellationToken.None).GetAwaiter().GetResult();
                Console.WriteLine("GOLDEN scale=" + scale + " rows=" + report.Observations.Count + " status=" + report.Status + " low=" + report.LowConfidence + " invalidDate=" + report.InvalidDate);
                Require(report.Status == OcrStatus.Read && report.Observations.Count >= 3, "real engine reads the synthetic numeric fields at scale " + scale);
                Require(report.Observations.All(o => o.Id == (123456781 + o.Time.Second - 10).ToString()
                    && o.Time.Date == Day && o.Time.Hour == 9 && o.Time.Minute == 10 && o.Time.Second >= 10 && o.Time.Second <= 13
                    && o.HandlingSeconds == 150 && o.QueueSeconds == 10), "accepted values exactly match independent synthetic truth at scale " + scale);
                Require(report.OtherDays == 1, "older day is recognized at scale " + scale);
                HashSet<int> selected = new HashSet<int> { 0 };
                byte[] png = Engine.Prepare(frame.Image, frame.Layout, Field.TaskId, selected);
                using (Bitmap masked = new Bitmap(new MemoryStream(png)))
                {
                    Rectangle column = frame.Layout.Columns[Field.TaskId]; Rectangle old = frame.Layout.Rows[4];
                    int x = 12 + (column.Width / 2) * 4, y = 12 + (old.Y - column.Y + old.Height / 2) * 4;
                    Require(masked.GetPixel(x, y).ToArgb() == Color.White.ToArgb(), "unselected historical ID pixels are masked at scale " + scale);
                }
                Array.Clear(png, 0, png.Length);
            }
            finally { frame.Clear(); }
        }
    }
    private static void Live(string executable, string fixture, Engine engine)
    {
        using (Process process = Process.Start(new ProcessStartInfo(fixture) { UseShellExecute = false }))
        {
            try
            {
                Target target = null; Stopwatch timer = Stopwatch.StartNew();
                while (timer.ElapsedMilliseconds < 5000)
                {
                    target = Discovery.Find().FirstOrDefault(t => t.ProcessId == process.Id);
                    if (target != null) break; Thread.Sleep(50);
                }
                Require(target != null, "live fixture discovered: " + Path.GetFileName(fixture));
                Thread.Sleep(150);
                Frame frame = FrameWorker.Run(executable, target, CancellationToken.None).GetAwaiter().GetResult();
                try
                {
                    Require(frame.Image.Status == CaptureStatus.Image && frame.Layout != null, "layout and capture come from the real native target (status=" + frame.Image.Status + ")");
                    Require(frame.Layout.Columns.Count == 4 && frame.Layout.Rows.Count == 5, "UIA provides all four headers and five row bands after column movement");
                    Report report = new Reader(engine).Read(frame.Image, frame.Layout, DateTime.Today, CancellationToken.None).GetAwaiter().GetResult();
                    Console.WriteLine("LIVE rows=" + report.Observations.Count + " status=" + report.Status + " invalidDate=" + report.InvalidDate + " low=" + report.LowConfidence);
                    Require(report.Observations.Count >= 3 && report.Observations.All(o => o.Id == (123456781 + o.Time.Second - 10).ToString() && o.HandlingSeconds == 150 && o.QueueSeconds == 10),
                        "native capture to local OCR returns only correct tasks");
                    Require(report.OtherDays == 1, "live previous-day row is excluded");
                }
                finally { frame.Clear(); }
            }
            finally { if (!process.HasExited) { process.Kill(); process.WaitForExit(1000); } }
        }
    }
    [STAThread] public static int Main(string[] args)
    {
        try
        {
            Native.SetDpiMode(); UnitTests(); Engine engine = new Engine(args[1]);
            byte[] binary = { 0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10, 0, 255, 128, 0 };
            ProcessStartInfo echoInfo = new ProcessStartInfo(args[2]) { WorkingDirectory = Path.GetDirectoryName(args[2]) };
            using (BinaryProcess echo = BinaryProcess.Start(echoInfo)) using (MemoryStream returned = new MemoryStream()) {
                echo.Input.Write(binary, 0, binary.Length); echo.Input.Close(); echo.Output.CopyTo(returned);
                Require(echo.WaitForExit(2000) && echo.ExitCode == 0 && returned.ToArray().SequenceEqual(binary), "binary PNG signature and arbitrary bytes cross the process boundary without a BOM");
            }
            Require(engine.Available, "portable engine and model are present"); GoldenTests(engine);
            foreach (string fixture in args.Skip(3)) Live(args[0], fixture, engine);
            Require(Process.GetProcessesByName("tesseract").Length == 0, "no OCR subprocess remains");
            Console.WriteLine("PASS total=" + checks); return 0;
        }
        catch (Exception error) { Console.WriteLine("FAIL " + error.GetType().Name + ": " + error.Message); return 1; }
    }
}
