using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.Clipboard;

public class ClipboardController
{
    private static readonly Lazy<ClipboardController> _instance = new(() => new ClipboardController());
    public static ClipboardController Instance => _instance.Value;

    public Task<string> GetTextAsync()
    {
        var tcs = new TaskCompletionSource<string>();
        var thread = new Thread(() =>
        {
            try
            {
                var text = System.Windows.Forms.Clipboard.ContainsText()
                    ? System.Windows.Forms.Clipboard.GetText()
                    : string.Empty;
                tcs.SetResult(text);
            }
            catch (Exception ex)
            {
                AppLogger.Instance.Warn("Clipboard", $"Failed to read clipboard: {ex.Message}");
                tcs.SetResult(string.Empty);
            }
        });

        thread.SetApartmentState(ApartmentState.STA);
        thread.IsBackground = true;
        thread.Start();

        return tcs.Task;
    }

    public Task<bool> SetTextAsync(string text)
    {
        var tcs = new TaskCompletionSource<bool>();
        var thread = new Thread(() =>
        {
            try
            {
                if (string.IsNullOrEmpty(text))
                {
                    System.Windows.Forms.Clipboard.Clear();
                }
                else
                {
                    System.Windows.Forms.Clipboard.SetText(text);
                }
                tcs.SetResult(true);
            }
            catch (Exception ex)
            {
                AppLogger.Instance.Warn("Clipboard", $"Failed to set clipboard: {ex.Message}");
                tcs.SetResult(false);
            }
        });

        thread.SetApartmentState(ApartmentState.STA);
        thread.IsBackground = true;
        thread.Start();

        return tcs.Task;
    }
}
