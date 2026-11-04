using System;
using System.IO;
public static class BinaryEcho
{
    public static void Main()
    {
        using (Stream input = Console.OpenStandardInput()) using (Stream output = Console.OpenStandardOutput()) input.CopyTo(output);
    }
}
