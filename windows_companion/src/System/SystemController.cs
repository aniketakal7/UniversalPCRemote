using System.Diagnostics;
using System.Runtime.InteropServices;
using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.SystemControl;

public class SystemController
{
    private static readonly Lazy<SystemController> _instance = new(() => new SystemController());
    public static SystemController Instance => _instance.Value;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    [DllImport("powrprof.dll", SetLastError = true)]
    private static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);

    public bool LockPC()
    {
        AppLogger.Instance.Info("System", "Locking workstation...");
        return LockWorkStation();
    }

    public bool SleepPC()
    {
        AppLogger.Instance.Info("System", "Putting workstation to sleep...");
        return SetSuspendState(false, true, false);
    }

    public void ShutdownPC()
    {
        AppLogger.Instance.Warn("System", "Executing PC Shutdown...");
        var psi = new ProcessStartInfo("shutdown.exe", "/s /t 10 /c \"Universal Remote Shutdown\"")
        {
            CreateNoWindow = true,
            UseShellExecute = false
        };
        Process.Start(psi);
    }

    public void RestartPC()
    {
        AppLogger.Instance.Warn("System", "Executing PC Restart...");
        var psi = new ProcessStartInfo("shutdown.exe", "/r /t 10 /c \"Universal Remote Restart\"")
        {
            CreateNoWindow = true,
            UseShellExecute = false
        };
        Process.Start(psi);
    }

    public void CancelShutdown()
    {
        AppLogger.Instance.Info("System", "Cancelling pending shutdown...");
        var psi = new ProcessStartInfo("shutdown.exe", "/a")
        {
            CreateNoWindow = true,
            UseShellExecute = false
        };
        Process.Start(psi);
    }

    public object GetSystemInfo()
    {
        var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
        var uptimeStr = $"{(int)uptime.TotalHours}h {uptime.Minutes}m";

        var powerStatus = SystemInformation.PowerStatus;
        var batteryPercent = (int)(powerStatus.BatteryLifePercent * 100);
        var isCharging = powerStatus.PowerLineStatus == PowerLineStatus.Online;

        return new
        {
            pcName = Environment.MachineName,
            osVersion = Environment.OSVersion.VersionString,
            processorCount = Environment.ProcessorCount,
            uptime = uptimeStr,
            batteryPercent = batteryPercent >= 0 && batteryPercent <= 100 ? batteryPercent : (int?)null,
            isCharging = isCharging,
            localTime = DateTime.Now.ToString("HH:mm:ss")
        };
    }
}
