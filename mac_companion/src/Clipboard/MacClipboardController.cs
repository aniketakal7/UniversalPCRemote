using System.Diagnostics;
using UniversalPCRemote.Mac.Logging;

namespace UniversalPCRemote.Mac.Clipboard;

public class MacClipboardController
{
    private static readonly Lazy<MacClipboardController> _instance = new(() => new MacClipboardController());
    public static MacClipboardController Instance => _instance.Value;

    public string? GetText()
    {
        if (!OperatingSystem.IsMacOS()) return null;

        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "pbpaste",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            var text = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(2000);
            return text;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Clipboard", "Failed to read macOS clipboard via pbpaste.", ex);
            return null;
        }
    }

    public bool SetText(string text)
    {
        if (!OperatingSystem.IsMacOS()) return false;

        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "pbcopy",
                    UseShellExecute = false,
                    RedirectStandardInput = true,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            proc.StandardInput.Write(text);
            proc.StandardInput.Close();
            proc.WaitForExit(2000);
            return true;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Clipboard", "Failed to write to macOS clipboard via pbcopy.", ex);
            return false;
        }
    }
}
