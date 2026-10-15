using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.Media;

public class MediaController
{
    private static readonly Lazy<MediaController> _instance = new(() => new MediaController());
    public static MediaController Instance => _instance.Value;

    private const ushort VK_VOLUME_MUTE = 0xAD;
    private const ushort VK_VOLUME_DOWN = 0xAE;
    private const ushort VK_VOLUME_UP = 0xAF;
    private const ushort VK_MEDIA_NEXT_TRACK = 0xB0;
    private const ushort VK_MEDIA_PREV_TRACK = 0xB1;
    private const ushort VK_MEDIA_STOP = 0xB2;
    private const ushort VK_MEDIA_PLAY_PAUSE = 0xB3;

    public void PlayPause()
    {
        SendMediaKey(VK_MEDIA_PLAY_PAUSE);
        AppLogger.Instance.Debug("Media", "Simulated Play/Pause media key.");
    }

    public void NextTrack()
    {
        SendMediaKey(VK_MEDIA_NEXT_TRACK);
        AppLogger.Instance.Debug("Media", "Simulated Next Track media key.");
    }

    public void PreviousTrack()
    {
        SendMediaKey(VK_MEDIA_PREV_TRACK);
        AppLogger.Instance.Debug("Media", "Simulated Previous Track media key.");
    }

    public void Stop()
    {
        SendMediaKey(VK_MEDIA_STOP);
        AppLogger.Instance.Debug("Media", "Simulated Stop media key.");
    }

    public void SeekBackward()
    {
        SendMediaKey(0x25); // Left Arrow: seek backward in common video players and browsers
        AppLogger.Instance.Debug("Media", "Sent seek backward key.");
    }

    public void SeekForward()
    {
        SendMediaKey(0x27); // Right Arrow: seek forward in common video players and browsers
        AppLogger.Instance.Debug("Media", "Sent seek forward key.");
    }

    public void VolumeUp(int steps = 1)
    {
        for (int i = 0; i < steps; i++)
        {
            SendMediaKey(VK_VOLUME_UP);
        }
        AppLogger.Instance.Debug("Media", $"Volume Up sent {steps} times.");
    }

    public void VolumeDown(int steps = 1)
    {
        for (int i = 0; i < steps; i++)
        {
            SendMediaKey(VK_VOLUME_DOWN);
        }
        AppLogger.Instance.Debug("Media", $"Volume Down sent {steps} times.");
    }

    public void VolumeMute()
    {
        SendMediaKey(VK_VOLUME_MUTE);
        AppLogger.Instance.Debug("Media", "Volume Mute toggled.");
    }

    private static void SendMediaKey(ushort vk)
    {
        // Use SpinWait micro-delay (~50μs) instead of Thread.Sleep(10) for
        // near-instant key press registration without blocking 10ms.
        NativeInputSimulator.Instance.SendVirtualKey(vk, true);
        Thread.SpinWait(3000);
        NativeInputSimulator.Instance.SendVirtualKey(vk, false);
    }
}
