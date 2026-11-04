// Deliberately stalls the real process/pipe boundary, independently of how Windows renders a hung window.
using System.Threading;
public static class StalledWorker
{
    public static void Main() { Thread.Sleep(10000); }
}
