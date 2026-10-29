using System.Diagnostics;
using UniversalPCRemote.Mac.Logging;

namespace UniversalPCRemote.Mac.Media;

public class MacMediaController
{
    private static readonly Lazy<MacMediaController> _instance = new(() => new MacMediaController());
    public static MacMediaController Instance => _instance.Value;

    public void PlayPause()
    {
        RunAppleScript(@"
            if application ""Spotify"" is running then
                tell application ""Spotify"" to playpause
            else if application ""Music"" is running then
                tell application ""Music"" to playpause
            else
                tell application ""Music"" to playpause
            end if
        ");
    }

    public void Next()
    {
        RunAppleScript(@"
            if application ""Spotify"" is running then
                tell application ""Spotify"" to next track
            else
                tell application ""Music"" to next track
            end if
        ");
    }

    public void Previous()
    {
        RunAppleScript(@"
            if application ""Spotify"" is running then
                tell application ""Spotify"" to previous track
            else
                tell application ""Music"" to previous track
            end if
        ");
    }

    public void Stop()
    {
        RunAppleScript(@"
            if application ""Spotify"" is running then
                tell application ""Spotify"" to pause
            else
                tell application ""Music"" to pause
            end if
        ");
    }

    public void VolumeUp(int step = 6)
    {
        RunAppleScript($"set volume output volume ((output volume of (get volume settings)) + {step})");
    }

    public void VolumeDown(int step = 6)
    {
        RunAppleScript($"set volume output volume ((output volume of (get volume settings)) - {step})");
    }

    public void VolumeMute()
    {
        RunAppleScript("set volume output muted (not (output muted of (get volume settings)))");
    }

    public object GetStatus()
    {
        var volStr = RunAppleScriptWithOutput("output volume of (get volume settings)");
        var muteStr = RunAppleScriptWithOutput("output muted of (get volume settings)");

        int.TryParse(volStr?.Trim(), out var vol);
        bool isMuted = muteStr?.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) == true;

        return new
        {
            volume = vol,
            muted = isMuted,
            state = "ready"
        };
    }

    private static void RunAppleScript(string script)
    {
        if (!OperatingSystem.IsMacOS()) return;

        try
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
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Media", $"AppleScript error: {ex.Message}");
        }
    }

    private static string? RunAppleScriptWithOutput(string script)
    {
        if (!OperatingSystem.IsMacOS()) return null;

        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "osascript",
                    Arguments = $"-e '{script.Replace("'", "'\\''")}'",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            var outText = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(3000);
            return outText;
        }
        catch
        {
            return null;
        }
    }
}
