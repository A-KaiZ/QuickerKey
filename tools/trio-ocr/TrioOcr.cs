// P1: numeric-column OCR and strict same-image row validation. No app integration or history scrolling.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Automation;
using QuickerKeys.CaptureProbe;

namespace QuickerKeys.Ocr
{
    public enum Field { Time, TaskId, Handling, Queue }
    public enum OcrStatus { Read, NoReadableRows, LayoutUnavailable, EngineUnavailable, EngineFailure, Timeout, Cancelled, DateChanged }

    public sealed class Layout
    {
        public Rectangle Body;
        public readonly Dictionary<Field, Rectangle> Columns = new Dictionary<Field, Rectangle>();
        public readonly List<Rectangle> Rows = new List<Rectangle>();
        public bool Valid(int width, int height)
        {
            Rectangle image = new Rectangle(0, 0, width, height);
            if (Body.Width < 1 || Body.Height < 1 || !image.Contains(Body) || Rows.Count > 1000
                || !Columns.ContainsKey(Field.Time) || !Columns.ContainsKey(Field.TaskId)) return false;
            foreach (Rectangle column in Columns.Values)
                if (column.Width < 4 || column.Y != Body.Y || column.Height != Body.Height || !Body.Contains(column)) return false;
            Rectangle[] sorted = Columns.Values.OrderBy(c => c.X).ToArray();
            for (int i = 1; i < sorted.Length; i++) if (sorted[i - 1].Right > sorted[i].Left) return false;
            int bottom = Body.Top;
            foreach (Rectangle row in Rows.OrderBy(r => r.Top))
            {
                if (row.X != Body.X || row.Width != Body.Width || row.Height < 4 || !Body.Contains(row) || row.Top < bottom) return false;
                bottom = row.Bottom;
            }
            return true;
        }
        public string Fingerprint()
        {
            StringBuilder s = new StringBuilder(Body.ToString());
            foreach (var column in Columns.OrderBy(c => c.Key)) s.Append('|').Append(column.Key).Append(':').Append(column.Value);
            foreach (Rectangle row in Rows.OrderBy(r => r.Top)) s.Append('|').Append(row);
            using (SHA256 hash = SHA256.Create()) return Convert.ToBase64String(hash.ComputeHash(Encoding.UTF8.GetBytes(s.ToString())));
        }
    }

    public static class LayoutReader
    {
        public static Field? HeaderKey(string name)
        {
            StringBuilder normalized = new StringBuilder();
            foreach (char ch in name.Normalize(NormalizationForm.FormD).ToLowerInvariant())
                if (Char.IsLetterOrDigit(ch)) normalized.Append(ch == 'ø' ? 'o' : ch);
            switch (normalized.ToString())
            {
                case "tidspunkt": return Field.Time;
                case "oppgaveid": case "oppgave": return Field.TaskId;
                case "behandltid": case "behandlingstid": return Field.Handling;
                case "kotid": case "koetid": return Field.Queue;
                default: return null;
            }
        }
        private static Rectangle RectangleOf(System.Windows.Rect bounds, Native.Rect window)
        {
            if (bounds.IsEmpty || Double.IsInfinity(bounds.X) || Double.IsNaN(bounds.X) || bounds.Width <= 0 || bounds.Height <= 0)
                return Rectangle.Empty;
            return Rectangle.FromLTRB((int)Math.Round(bounds.Left - window.Left), (int)Math.Round(bounds.Top - window.Top),
                (int)Math.Round(bounds.Right - window.Left), (int)Math.Round(bounds.Bottom - window.Top));
        }
        // Called only on the bounded worker's MTA thread. Only header Names and row rectangles are requested.
        public static Layout Read(IntPtr list, Native.Rect window)
        {
            long header = Native.Message(list, 0x101F, 0, 0);
            Native.Rect headerBounds, client;
            Native.Point origin = new Native.Point();
            if (header <= 0 || !Native.GetWindowRect(new IntPtr(header), out headerBounds)
                || !Native.GetClientRect(list, out client) || !Native.ClientToScreen(list, ref origin)) return null;
            Layout layout = new Layout { Body = Rectangle.FromLTRB(origin.X - window.Left,
                Math.Max(origin.Y, headerBounds.Bottom) - window.Top, origin.X + client.Right - window.Left,
                origin.Y + client.Bottom - window.Top) };
            if (layout.Body.Width < 1 || layout.Body.Height < 1) return null;
            HashSet<Field> duplicates = new HashSet<Field>();
            AutomationElement root = AutomationElement.FromHandle(new IntPtr(header));
            AutomationElementCollection headings = root.FindAll(TreeScope.Descendants,
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.HeaderItem));
            if (headings.Count > 100) return null;
            foreach (AutomationElement heading in headings)
            {
                Field? key = HeaderKey(heading.Current.Name);
                if (!key.HasValue) continue;
                Rectangle bounds = RectangleOf(heading.Current.BoundingRectangle, window);
                Rectangle column = new Rectangle(bounds.X, layout.Body.Y, bounds.Width, layout.Body.Height);
                if (bounds.Width < 4 || !layout.Body.Contains(column)) continue; // Hidden/clipped columns stay unknown.
                if (layout.Columns.ContainsKey(key.Value)) duplicates.Add(key.Value);
                else layout.Columns.Add(key.Value, column);
            }
            foreach (Field duplicate in duplicates) layout.Columns.Remove(duplicate);
            AutomationElement listElement = AutomationElement.FromHandle(list);
            AutomationElementCollection items = listElement.FindAll(TreeScope.Children, new OrCondition(
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem),
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.DataItem)));
            if (items.Count > 5000) return null;
            HashSet<string> seen = new HashSet<string>();
            foreach (AutomationElement item in items)
            {
                Rectangle bounds = RectangleOf(item.Current.BoundingRectangle, window);
                if (bounds.Height < 4 || bounds.Top < layout.Body.Top || bounds.Bottom > layout.Body.Bottom) continue;
                Rectangle row = new Rectangle(layout.Body.X, bounds.Y, layout.Body.Width, bounds.Height);
                if (seen.Add(row.Y + ":" + row.Height)) layout.Rows.Add(row);
            }
            layout.Rows.Sort((a, b) => a.Top.CompareTo(b.Top));
            return layout.Valid(window.Right - window.Left, window.Bottom - window.Top) ? layout : null;
        }
    }

    public sealed class Word
    {
        public string Text;
        public RectangleF Bounds;
        public double Confidence;
    }
    public sealed class Cell
    {
        public string Text = "";
        public double Confidence = 100;
        public bool Conflict;
    }
    public sealed class Observation
    {
        public string Id;
        public DateTime Time;
        public int? HandlingSeconds, QueueSeconds;
        public string Key { get { return Id + "|" + Time.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture); } }
    }
    public sealed class Report
    {
        public OcrStatus Status = OcrStatus.NoReadableRows;
        public int CandidateRows, OtherDays, InvalidDate, InvalidId, MissingCore, Conflicts, LowConfidence, UnknownHandling, UnknownQueue;
        public readonly List<Observation> Observations = new List<Observation>();
        public string Summary()
        {
            int handlingN = Observations.Count(o => o.HandlingSeconds.HasValue), queueN = Observations.Count(o => o.QueueSeconds.HasValue);
            return "OCR-utfall: " + Status + "\r\nKandidatrader: " + CandidateRows + " | formatvaliderte i dag: " + Observations.Count
                + " | andre dager: " + OtherDays + "\r\nAvvist – dato/tid: " + InvalidDate + ", ID: " + InvalidId
                + ", manglende felt: " + MissingCore + ", cellekonflikter: " + Conflicts + ", lav konfidens: " + LowConfidence
                + "\r\nBehandlingstid kjent: " + handlingN + "/" + Observations.Count + " | køtid kjent: " + queueN + "/" + Observations.Count
                + "\r\nSamlet kjent behandlingstid: " + (handlingN > 0 ? Duration(Observations.Where(o => o.HandlingSeconds.HasValue).Sum(o => (long)o.HandlingSeconds.Value)) : "ukjent")
                + "\r\nSnitt behandlingstid (kjente): " + (handlingN > 0 ? Duration((int)Math.Round(Observations.Where(o => o.HandlingSeconds.HasValue).Average(o => o.HandlingSeconds.Value), MidpointRounding.AwayFromZero)) : "ukjent")
                + "\r\nSnitt køtid (kjente): " + (queueN > 0 ? Duration((int)Math.Round(Observations.Where(o => o.QueueSeconds.HasValue).Average(o => o.QueueSeconds.Value), MidpointRounding.AwayFromZero)) : "ukjent")
                + "\r\nBare dette bildeutsnittet. Ikke bekreftet over flere fangster eller som dagens total. Ingen QuickerKeys-import.";
        }
        private static string Duration(long seconds) { return (seconds / 3600) + ":" + ((seconds / 60) % 60).ToString("D2") + ":" + (seconds % 60).ToString("D2"); }
    }

    public static class Validator
    {
        // A rejection threshold for this experimental profile, not a probability of correctness.
        public const double MinimumConfidence = 60;
        public static Cell[] Cells(Layout layout, Field field, IEnumerable<Word> words)
        {
            Cell[] cells = layout.Rows.Select(r => new Cell()).ToArray();
            List<Word>[] assigned = layout.Rows.Select(r => new List<Word>()).ToArray();
            Rectangle column = layout.Columns[field];
            foreach (Word word in words)
            {
                if (word.Text.Length == 0) continue;
                int[] rows = layout.Rows.Select((r, i) => new { Row = r, Index = i })
                    .Where(r => word.Bounds.Bottom > r.Row.Top && word.Bounds.Top < r.Row.Bottom).Select(r => r.Index).ToArray();
                bool inColumn = word.Bounds.Left >= column.Left && word.Bounds.Right <= column.Right;
                if (rows.Length != 1 || !inColumn || word.Bounds.Top < layout.Rows[rows[0]].Top || word.Bounds.Bottom > layout.Rows[rows[0]].Bottom)
                { foreach (int row in rows) cells[row].Conflict = true; continue; }
                assigned[rows[0]].Add(word);
            }
            for (int i = 0; i < cells.Length; i++)
            {
                Word[] ordered = assigned[i].OrderBy(w => w.Bounds.Left).ToArray();
                cells[i].Text = String.Join(" ", ordered.Select(w => w.Text));
                if (ordered.Length > 0) cells[i].Confidence = ordered.Min(w => w.Confidence);
                for (int j = 1; j < ordered.Length; j++) if (ordered[j - 1].Bounds.Right > ordered[j].Bounds.Left) cells[i].Conflict = true;
            }
            return cells;
        }
        public static bool Timestamp(string text, out DateTime time)
        {
            time = default(DateTime);
            string normalized = Regex.Replace(text.Trim(), @"\s+", " ");
            return Regex.IsMatch(normalized, @"^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}$")
                && DateTime.TryParseExact(normalized, "dd.MM.yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out time);
        }
        public static int? Seconds(Cell cell)
        {
            if (cell == null || cell.Conflict || cell.Confidence < MinimumConfidence) return null;
            string value = cell.Text.Trim();
            Match match = Regex.Match(value, @"^(?:([0-9]{1,3}):)?([0-9]{2}):([0-5][0-9])$");
            if (!match.Success) return null;
            int first = Int32.Parse(match.Groups[2].Value), last = Int32.Parse(match.Groups[3].Value);
            if (match.Groups[1].Success)
            {
                if (first > 59) return null;
                return Int32.Parse(match.Groups[1].Value) * 3600 + first * 60 + last;
            }
            return first * 60 + last;
        }
        public static Report Evaluate(Layout layout, Dictionary<Field, Cell[]> data, DateTime date)
        {
            Report report = new Report { CandidateRows = layout.Rows.Count };
            Dictionary<string, Observation> unique = new Dictionary<string, Observation>();
            HashSet<string> quarantined = new HashSet<string>();
            for (int i = 0; i < layout.Rows.Count; i++)
            {
                Cell timeCell = data[Field.Time][i], idCell = data.ContainsKey(Field.TaskId) ? data[Field.TaskId][i] : null;
                DateTime time;
                if (timeCell.Conflict) { report.Conflicts++; continue; }
                if (timeCell.Text.Length == 0) { report.MissingCore++; continue; }
                if (timeCell.Confidence < MinimumConfidence) { report.LowConfidence++; continue; }
                if (!Timestamp(timeCell.Text, out time)) { report.InvalidDate++; continue; }
                if (time.Date != date.Date) { report.OtherDays++; continue; }
                if (idCell == null || idCell.Text.Length == 0) { report.MissingCore++; continue; }
                if (idCell.Conflict) { report.Conflicts++; continue; }
                if (idCell.Confidence < MinimumConfidence) { report.LowConfidence++; continue; }
                if (!Regex.IsMatch(idCell.Text, @"^[0-9]{9}$")) { report.InvalidId++; continue; }
                Observation observation = new Observation { Id = idCell.Text, Time = time,
                    HandlingSeconds = data.ContainsKey(Field.Handling) ? Seconds(data[Field.Handling][i]) : null,
                    QueueSeconds = data.ContainsKey(Field.Queue) ? Seconds(data[Field.Queue][i]) : null };
                if (!observation.HandlingSeconds.HasValue) report.UnknownHandling++;
                if (!observation.QueueSeconds.HasValue) report.UnknownQueue++;
                if (quarantined.Contains(observation.Key)) continue;
                Observation previous;
                if (unique.TryGetValue(observation.Key, out previous))
                {
                    if (previous.HandlingSeconds != observation.HandlingSeconds || previous.QueueSeconds != observation.QueueSeconds)
                    { unique.Remove(observation.Key); quarantined.Add(observation.Key); report.Conflicts++; }
                }
                else unique.Add(observation.Key, observation);
            }
            report.Observations.AddRange(unique.Values.OrderByDescending(o => o.Time));
            report.Status = report.Observations.Count > 0 ? OcrStatus.Read : OcrStatus.NoReadableRows;
            return report;
        }
    }

    public sealed class EngineException : Exception
    {
        public readonly OcrStatus Status;
        public EngineException(OcrStatus status) { Status = status; }
        public EngineException(OcrStatus status, Exception inner) : base("OCR engine failure", inner) { Status = status; }
    }

    public sealed class Engine
    {
        public readonly string Directory;
        public Engine(string directory) { Directory = Path.GetFullPath(directory); }
        public bool Available { get { return File.Exists(Path.Combine(Directory, "tesseract.exe")) && File.Exists(Path.Combine(Directory, "tessdata", "eng.traineddata")); } }
        private static async Task<byte[]> ReadBounded(Stream stream, int maximum)
        {
            using (MemoryStream memory = new MemoryStream())
            {
                byte[] buffer = new byte[4096]; int size;
                while ((size = await stream.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) > 0)
                {
                    if (memory.Length + size > maximum) throw new InvalidDataException();
                    memory.Write(buffer, 0, size);
                }
                return memory.ToArray();
            }
        }
        public async Task<List<Word>> Read(CaptureResult image, Layout layout, Field field, HashSet<int> selected, CancellationToken cancel)
        {
            if (!Available) throw new EngineException(OcrStatus.EngineUnavailable);
            byte[] png = Prepare(image, layout, field, selected);
            ProcessStartInfo start = new ProcessStartInfo(Path.Combine(Directory, "tesseract.exe"), "stdin stdout --oem 1 --psm 6 -l eng tsv");
            start.UseShellExecute = false; start.CreateNoWindow = true; start.WorkingDirectory = Directory;
            start.RedirectStandardInput = true; start.RedirectStandardOutput = true; start.RedirectStandardError = true;
            start.EnvironmentVariables["OMP_THREAD_LIMIT"] = "1";
            start.EnvironmentVariables["TESSDATA_PREFIX"] = Path.Combine(Directory, "tessdata");
            start.EnvironmentVariables["PATH"] = Directory + ";" + Environment.GetFolderPath(Environment.SpecialFolder.System);
            using (Process process = new Process { StartInfo = start })
            {
                Task<byte[]> output = null, error = null;
                Task combined = null;
                try
                {
                    cancel.ThrowIfCancellationRequested(); process.Start();
                    output = ReadBounded(process.StandardOutput.BaseStream, 2 * 1024 * 1024);
                    error = ReadBounded(process.StandardError.BaseStream, 128 * 1024);
                    Task input = SendInput(process, png);
                    combined = Task.WhenAll(output, error, input);
                    if (await Task.WhenAny(combined, Task.Delay(6000, cancel)).ConfigureAwait(false) != combined)
                        throw new EngineException(cancel.IsCancellationRequested ? OcrStatus.Cancelled : OcrStatus.Timeout);
                    await combined.ConfigureAwait(false);
                    if (!process.WaitForExit(500) || process.ExitCode != 0) throw new EngineException(OcrStatus.EngineFailure);
                    string text = Encoding.UTF8.GetString(output.Result);
                    Array.Clear(output.Result, 0, output.Result.Length); Array.Clear(error.Result, 0, error.Result.Length);
                    return ParseTsv(text, layout.Columns[field]);
                }
                catch (OperationCanceledException) { throw new EngineException(OcrStatus.Cancelled); }
                catch (EngineException) { throw; }
                catch (Exception failure) { throw new EngineException(OcrStatus.EngineFailure, failure); }
                finally
                {
                    Array.Clear(png, 0, png.Length);
                    try { if (!process.HasExited) process.Kill(); process.WaitForExit(500); } catch { }
                    if (combined != null) Observe(combined, output, error);
                }
            }
        }
        private static void Observe(Task combined, Task<byte[]> output, Task<byte[]> error)
        {
            combined.ContinueWith(delegate(Task task) {
                if (task.IsFaulted) { var ignored = task.Exception; }
                if (output.Status == TaskStatus.RanToCompletion) Array.Clear(output.Result, 0, output.Result.Length);
                if (error.Status == TaskStatus.RanToCompletion) Array.Clear(error.Result, 0, error.Result.Length);
            }, TaskScheduler.Default);
        }
        private static async Task SendInput(Process process, byte[] png)
        {
            await process.StandardInput.BaseStream.WriteAsync(png, 0, png.Length).ConfigureAwait(false);
            process.StandardInput.Close();
        }
        public static List<Word> ParseTsv(string text, Rectangle column)
        {
            List<Word> words = new List<Word>();
            foreach (string line in text.Split('\n'))
            {
                string[] parts = line.TrimEnd('\r').Split('\t');
                if (parts.Length != 12 || parts[0] != "5" || parts[11].Length == 0) continue;
                int x, y, width, height; double confidence;
                if (!Int32.TryParse(parts[6], out x) || !Int32.TryParse(parts[7], out y)
                    || !Int32.TryParse(parts[8], out width) || !Int32.TryParse(parts[9], out height)
                    || !Double.TryParse(parts[10], NumberStyles.Float, CultureInfo.InvariantCulture, out confidence)
                    || x < 0 || y < 0 || width <= 0 || height <= 0 || Double.IsNaN(confidence) || confidence < 0 || confidence > 100) continue;
                words.Add(new Word { Text = parts[11], Confidence = confidence,
                    Bounds = new RectangleF(column.X + (x - 12) / 4f, column.Y + (y - 12) / 4f, width / 4f, height / 4f) });
                if (words.Count > 10000) throw new EngineException(OcrStatus.EngineFailure);
            }
            return words;
        }
        // Only the selected numeric column/row pixels enter the engine; all other pixels become white.
        public static byte[] Prepare(CaptureResult image, Layout layout, Field field, HashSet<int> selected)
        {
            Rectangle column = layout.Columns[field];
            if ((long)(column.Width * 4 + 24) * (column.Height * 4 + 24) > 20000000) throw new EngineException(OcrStatus.EngineFailure);
            using (Bitmap crop = new Bitmap(column.Width, column.Height, PixelFormat.Format24bppRgb))
            {
                BitmapData bits = crop.LockBits(new Rectangle(0, 0, crop.Width, crop.Height), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
                byte[] data = new byte[Math.Abs(bits.Stride) * crop.Height];
                for (int i = 0; i < data.Length; i++) data[i] = 255;
                try
                {
                    for (int rowIndex = 0; rowIndex < layout.Rows.Count; rowIndex++)
                    {
                        if (selected != null && !selected.Contains(rowIndex)) continue;
                        Rectangle row = layout.Rows[rowIndex];
                        int[] samples = { Light(image, column.Left + 1, row.Top + 1), Light(image, column.Right - 2, row.Top + 1),
                            Light(image, column.Left + 1, row.Bottom - 2), Light(image, column.Right - 2, row.Bottom - 2) };
                        Array.Sort(samples); int background = Math.Max(1, Math.Min(254, (samples[1] + samples[2]) / 2));
                        for (int y = row.Top; y < row.Bottom; y++) for (int x = column.Left + 1; x < column.Right - 1; x++)
                        {
                            int light = Light(image, x, y);
                            int normalized = background < 128 ? 255 - Math.Max(0, light - background) * 255 / (255 - background) : light * 255 / background;
                            byte value = (byte)Math.Max(0, Math.Min(255, normalized));
                            int offset = (y - column.Y) * bits.Stride + (x - column.X) * 3;
                            data[offset] = value; data[offset + 1] = value; data[offset + 2] = value;
                        }
                    }
                    System.Runtime.InteropServices.Marshal.Copy(data, 0, bits.Scan0, data.Length);
                }
                finally { crop.UnlockBits(bits); Array.Clear(data, 0, data.Length); }
                using (Bitmap scaled = new Bitmap(column.Width * 4 + 24, column.Height * 4 + 24, PixelFormat.Format24bppRgb))
                {
                    using (Graphics graphics = Graphics.FromImage(scaled))
                    {
                        graphics.Clear(Color.White); graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        graphics.DrawImage(crop, new Rectangle(12, 12, column.Width * 4, column.Height * 4));
                    }
                    using (MemoryStream memory = new MemoryStream()) { scaled.Save(memory, ImageFormat.Png); return memory.ToArray(); }
                }
            }
        }
        private static int Light(CaptureResult image, int x, int y)
        {
            int offset = (y * image.Width + x) * 4;
            return (image.Pixels[offset] * 29 + image.Pixels[offset + 1] * 150 + image.Pixels[offset + 2] * 77) >> 8;
        }
    }

    public sealed class Reader
    {
        private readonly Engine engine;
        public Reader(Engine value) { engine = value; }
        public async Task<Report> Read(CaptureResult image, Layout layout, DateTime date, CancellationToken cancel)
        {
            if (image == null || image.Pixels == null || layout == null || !layout.Valid(image.Width, image.Height))
                return new Report { Status = OcrStatus.LayoutUnavailable };
            if (!engine.Available) return new Report { Status = OcrStatus.EngineUnavailable };
            try
            {
                Dictionary<Field, Cell[]> data = new Dictionary<Field, Cell[]>();
                data[Field.Time] = Validator.Cells(layout, Field.Time, await engine.Read(image, layout, Field.Time, null, cancel).ConfigureAwait(false));
                HashSet<int> today = new HashSet<int>();
                for (int i = 0; i < layout.Rows.Count; i++)
                {
                    Cell cell = data[Field.Time][i]; DateTime time;
                    if (!cell.Conflict && cell.Confidence >= Validator.MinimumConfidence && Validator.Timestamp(cell.Text, out time) && time.Date == date.Date) today.Add(i);
                }
                if (today.Count > 0) foreach (Field field in new[] { Field.TaskId, Field.Handling, Field.Queue })
                    if (layout.Columns.ContainsKey(field)) data[field] = Validator.Cells(layout, field, await engine.Read(image, layout, field, today, cancel).ConfigureAwait(false));
                cancel.ThrowIfCancellationRequested();
                return Validator.Evaluate(layout, data, date);
            }
            catch (EngineException error) { return new Report { Status = error.Status }; }
            catch (OperationCanceledException) { return new Report { Status = OcrStatus.Cancelled }; }
            catch { return new Report { Status = OcrStatus.EngineFailure }; }
        }
    }
}
