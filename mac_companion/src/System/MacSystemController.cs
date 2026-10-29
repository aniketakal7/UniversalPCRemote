using System.Diagnostics;
using UniversalPCRemote.Mac.Logging;

namespace UniversalPCRemote.Mac.SystemControl;

public class MacSystemController
{
    private static readonly Lazy<MacSystemController> _instance = new(() => new MacSystemController());
    public static MacSystemController Instance => _instance.Value;

    public bool LockMac()
    {
        if (!OperatingSystem.IsMacOS()) return false;

        try
        {
            // Standard macOS lock display command
            Process.Start("pmset", "displaysleepnow")?.WaitForExit(2000);
            return true;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("System", "Failed to lock Mac.", ex);
            return false;
        }
    }

    public bool SleepMac()
    {
        if (!OperatingSystem.IsMacOS()) return false;

        try
        {
            RunAppleScript("tell application \"System Events\" to sleep");
            return true;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("System", "Failed to put Mac to sleep.", ex);
            return false;
        }
    }

    public bool RestartMac()
    {
        if (!OperatingSystem.IsMacOS()) return false;

        try
        {
            RunAppleScript("tell application \"System Events\" to restart");
            return true;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("System", "Failed to restart Mac.", ex);
            return false;
        }
    }

    public bool ShutdownMac()
    {
        if (!OperatingSystem.IsMacOS()) return false;

        try
        {
            RunAppleScript("tell application \"System Events\" to shut down");
            return true;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("System", "Failed to shut down Mac.", ex);
            return false;
        }
    }

    public void CancelShutdown()
    {
        // On macOS AppleScript shutdown triggers immediately or prompts; logging notice
        AppLogger.Instance.Info("System", "Cancel shutdown requested.");
    }

    public object GetSystemInfo()
    {
        return new
        {
            machineName = Environment.MachineName,
            os = "macOS",
            version = Environment.OSVersion.VersionString,
            uptime = TimeSpan.FromMilliseconds(Environment.TickCount64).ToString(@"d\.hh\:mm\:ss"),
            processorCount = Environment.ProcessorCount,
            battery = GetBatteryPercent()
        };
    }

    private string GetBatteryPercent()
    {
        if (!OperatingSystem.IsMacOS()) return "AC Connected";

        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "pmset",
                    Arguments = "-g batt",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            var outText = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(2000);

            // Output sample: Now drawing from 'Battery Power' -InternalBattery-0 (id=...) 95%; discharging...
            var percentIdx = outText.IndexOf('%');
            if (percentIdx > 0)
            {
                var start = outText.LastIndexOf('\t', percentIdx);
                if (start < 0) start = outText.LastIndexOf(' ', percentIdx);
                if (start >= 0 && start < percentIdx)
                    return outText.Substring(start + 1, percentIdx - start) + "%";
            }
        }
        catch { }

        return "N/A";
    }

    private static void RunAppleScript(string script)
    {
        using var proc = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "osascript",
                Arguments = $"-e '{script.Replace("'", "'\\''")}'",
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };
        proc.Start();
        proc.WaitForExit(3000);
    }
}
