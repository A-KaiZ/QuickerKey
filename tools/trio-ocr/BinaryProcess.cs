// .NET Framework Process redirection can emit an encoding preamble before binary input.
// Create the child with raw inherited pipe handles instead; no text writer touches PNG bytes.
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace QuickerKeys.Ocr
{
    public sealed class BinaryProcess : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)] private struct Security
        { public int Length; public IntPtr Descriptor; public int Inherit; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct Startup
        {
            public int Size; public string Reserved, Desktop, Title;
            public int X, Y, Width, Height, XChars, YChars, Fill, Flags;
            public short Show, ReservedSize; public IntPtr ReservedData, Input, Output, Error;
        }
        [StructLayout(LayoutKind.Sequential)] private struct Created
        { public IntPtr Process, Thread; public int Pid, Tid; }
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool CreatePipe(out IntPtr read, out IntPtr write, ref Security security, int size);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetHandleInformation(IntPtr handle, int mask, int flags);
        [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GetExitCodeProcess(IntPtr handle, out uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool TerminateProcess(IntPtr handle, uint exitCode);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool CreateProcess(
            string application, StringBuilder command, IntPtr processSecurity, IntPtr threadSecurity, bool inherit,
            int flags, IntPtr environment, string directory, ref Startup startup, out Created created);
        private IntPtr child;
        public FileStream Input, Output, Error;
        public bool WaitForExit(int milliseconds)
        {
            uint result = WaitForSingleObject(child, checked((uint)milliseconds));
            if (result == UInt32.MaxValue) throw new Win32Exception(Marshal.GetLastWin32Error());
            return result == 0;
        }
        public uint ExitCode
        {
            get { uint code; if (!GetExitCodeProcess(child, out code)) throw new Win32Exception(Marshal.GetLastWin32Error()); return code; }
        }
        private static void Close(ref IntPtr handle) { if (handle != IntPtr.Zero) CloseHandle(handle); handle = IntPtr.Zero; }
        public static BinaryProcess Start(ProcessStartInfo info)
        {
            IntPtr inRead = IntPtr.Zero, inWrite = IntPtr.Zero, outRead = IntPtr.Zero, outWrite = IntPtr.Zero,
                errRead = IntPtr.Zero, errWrite = IntPtr.Zero, environment = IntPtr.Zero;
            Created created = new Created(); BinaryProcess process = new BinaryProcess();
            try
            {
                Security security = new Security { Length = Marshal.SizeOf(typeof(Security)), Inherit = 1 };
                if (!CreatePipe(out inRead, out inWrite, ref security, 0) || !CreatePipe(out outRead, out outWrite, ref security, 0)
                    || !CreatePipe(out errRead, out errWrite, ref security, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
                if (!SetHandleInformation(inWrite, 1, 0) || !SetHandleInformation(outRead, 1, 0) || !SetHandleInformation(errRead, 1, 0))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                StringBuilder variables = new StringBuilder();
                foreach (string key in info.EnvironmentVariables.Keys.Cast<string>().OrderBy(k => k, StringComparer.OrdinalIgnoreCase))
                    variables.Append(key).Append('=').Append(info.EnvironmentVariables[key]).Append('\0');
                variables.Append('\0'); environment = Marshal.StringToHGlobalUni(variables.ToString());
                Startup startup = new Startup { Size = Marshal.SizeOf(typeof(Startup)), Flags = 0x100,
                    Input = inRead, Output = outWrite, Error = errWrite };
                StringBuilder command = new StringBuilder("\"" + info.FileName + "\" " + info.Arguments);
                if (!CreateProcess(info.FileName, command, IntPtr.Zero, IntPtr.Zero, true, 0x08000400, environment,
                    info.WorkingDirectory, ref startup, out created)) throw new Win32Exception(Marshal.GetLastWin32Error());
                // Retain the CreateProcess handle, including when the child exits immediately.
                process.child = created.Process; created.Process = IntPtr.Zero;
                process.Input = new FileStream(new SafeFileHandle(inWrite, true), FileAccess.Write, 4096, false); inWrite = IntPtr.Zero;
                process.Output = new FileStream(new SafeFileHandle(outRead, true), FileAccess.Read, 4096, false); outRead = IntPtr.Zero;
                process.Error = new FileStream(new SafeFileHandle(errRead, true), FileAccess.Read, 4096, false); errRead = IntPtr.Zero;
                return process;
            }
            catch { process.Dispose(); throw; }
            finally
            {
                Close(ref inRead); Close(ref inWrite); Close(ref outRead); Close(ref outWrite); Close(ref errRead); Close(ref errWrite);
                Close(ref created.Process); Close(ref created.Thread);
                if (environment != IntPtr.Zero) Marshal.FreeHGlobal(environment);
            }
        }
        public void Dispose()
        {
            if (child != IntPtr.Zero) { try { if (!WaitForExit(0)) TerminateProcess(child, 1); WaitForExit(500); } catch { } Close(ref child); }
            if (Input != null) { Input.Dispose(); Input = null; }
            if (Output != null) { Output.Dispose(); Output = null; }
            if (Error != null) { Error.Dispose(); Error = null; }
        }
    }
}
