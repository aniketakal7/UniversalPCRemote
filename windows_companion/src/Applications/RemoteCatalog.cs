using System.Text.Json.Serialization;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Applications;

public class RemoteActionDefinition
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;

    [JsonPropertyName("actionType")]
    public string ActionType { get; set; } = string.Empty; // "key_combination", "key", "media"

    [JsonPropertyName("key")]
    public string? Key { get; set; }

    [JsonPropertyName("modifiers")]
    public List<string>? Modifiers { get; set; }

    [JsonPropertyName("mediaAction")]
    public string? MediaAction { get; set; }
}

public class RemoteButtonDefinition
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;

    [JsonPropertyName("icon")]
    public string Icon { get; set; } = string.Empty;

    [JsonPropertyName("actionId")]
    public string ActionId { get; set; } = string.Empty;

    [JsonPropertyName("colorHex")]
    public string? ColorHex { get; set; }
}

public class RemoteDefinition
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("buttons")]
    public List<RemoteButtonDefinition> Buttons { get; set; } = new();

    [JsonPropertyName("actions")]
    public List<RemoteActionDefinition> Actions { get; set; } = new();
}

public class RemoteCatalog
{
    private static readonly Lazy<RemoteCatalog> _instance = new(() => new RemoteCatalog());
    public static RemoteCatalog Instance => _instance.Value;

    private readonly Dictionary<string, RemoteDefinition> _remotes = new(StringComparer.OrdinalIgnoreCase);

    public RemoteCatalog()
    {
        InitializeDefaultRemotes();
    }

    public IReadOnlyList<RemoteDefinition> GetAllRemotes() => _remotes.Values.ToList();

    public RemoteDefinition? GetRemote(string id) => _remotes.TryGetValue(id, out var r) ? r : null;

    private void InitializeDefaultRemotes()
    {
        // 1. VLC Remote
        var vlc = new RemoteDefinition
        {
            Id = "vlc",
            Name = "VLC Media Player",
            Category = "Media",
            Description = "Controls VLC media playback and navigation shortcuts."
        };
        vlc.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "play_pause", Label = "Play / Pause", ActionType = "key", Key = "SPACE" },
            new RemoteActionDefinition { Id = "next", Label = "Next Track", ActionType = "key", Key = "N" },
            new RemoteActionDefinition { Id = "prev", Label = "Previous Track", ActionType = "key", Key = "P" },
            new RemoteActionDefinition { Id = "fullscreen", Label = "Fullscreen", ActionType = "key", Key = "F" },
            new RemoteActionDefinition { Id = "subtitles", Label = "Toggle Subtitles", ActionType = "key", Key = "V" },
            new RemoteActionDefinition { Id = "vol_up", Label = "Volume Up", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "UP" },
            new RemoteActionDefinition { Id = "vol_down", Label = "Volume Down", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "DOWN" },
            new RemoteActionDefinition { Id = "mute", Label = "Mute", ActionType = "key", Key = "M" }
        });
        vlc.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_play", Label = "Play/Pause", Icon = "play_arrow", ActionId = "play_pause" },
            new RemoteButtonDefinition { Id = "b_next", Label = "Next", Icon = "skip_next", ActionId = "next" },
            new RemoteButtonDefinition { Id = "b_prev", Label = "Prev", Icon = "skip_previous", ActionId = "prev" },
            new RemoteButtonDefinition { Id = "b_fs", Label = "Fullscreen", Icon = "fullscreen", ActionId = "fullscreen" },
            new RemoteButtonDefinition { Id = "b_sub", Label = "Subtitles", Icon = "subtitles", ActionId = "subtitles" },
            new RemoteButtonDefinition { Id = "b_vol_up", Label = "Vol +", Icon = "volume_up", ActionId = "vol_up" },
            new RemoteButtonDefinition { Id = "b_vol_down", Label = "Vol -", Icon = "volume_down", ActionId = "vol_down" },
            new RemoteButtonDefinition { Id = "b_mute", Label = "Mute", Icon = "volume_off", ActionId = "mute" }
        });
        _remotes[vlc.Id] = vlc;

        // 2. Browser & YouTube Remote
        var browser = new RemoteDefinition
        {
            Id = "browser",
            Name = "Web Browser / YouTube",
            Category = "Web",
            Description = "Tabs and playback shortcuts for Chrome, Edge, and Firefox."
        };
        browser.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "tab_next", Label = "Next Tab", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "TAB" },
            new RemoteActionDefinition { Id = "tab_prev", Label = "Prev Tab", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "TAB" },
            new RemoteActionDefinition { Id = "tab_new", Label = "New Tab", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "T" },
            new RemoteActionDefinition { Id = "tab_close", Label = "Close Tab", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "W" },
            new RemoteActionDefinition { Id = "reload", Label = "Reload", ActionType = "key", Key = "F5" },
            new RemoteActionDefinition { Id = "space", Label = "Play/Pause", ActionType = "key", Key = "SPACE" },
            new RemoteActionDefinition { Id = "fs", Label = "Fullscreen", ActionType = "key", Key = "F" },
            new RemoteActionDefinition { Id = "seek_back", Label = "Rewind 5s", ActionType = "key", Key = "LEFT" },
            new RemoteActionDefinition { Id = "seek_fwd", Label = "Forward 5s", ActionType = "key", Key = "RIGHT" }
        });
        browser.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_tab_prev", Label = "Prev Tab", Icon = "arrow_back", ActionId = "tab_prev" },
            new RemoteButtonDefinition { Id = "b_tab_next", Label = "Next Tab", Icon = "arrow_forward", ActionId = "tab_next" },
            new RemoteButtonDefinition { Id = "b_tab_new", Label = "New Tab", Icon = "add", ActionId = "tab_new" },
            new RemoteButtonDefinition { Id = "b_tab_close", Label = "Close Tab", Icon = "close", ActionId = "tab_close" },
            new RemoteButtonDefinition { Id = "b_space", Label = "Play/Pause", Icon = "play_arrow", ActionId = "space" },
            new RemoteButtonDefinition { Id = "b_reload", Label = "Refresh", Icon = "refresh", ActionId = "reload" },
            new RemoteButtonDefinition { Id = "b_seek_back", Label = "-5s", Icon = "replay_5", ActionId = "seek_back" },
            new RemoteButtonDefinition { Id = "b_seek_fwd", Label = "+5s", Icon = "forward_5", ActionId = "seek_fwd" },
            new RemoteButtonDefinition { Id = "b_fs", Label = "Fullscreen", Icon = "fullscreen", ActionId = "fs" }
        });
        _remotes[browser.Id] = browser;

        // 3. Presentation Remote (PowerPoint / Keynote / Slides)
        var presentation = new RemoteDefinition
        {
            Id = "presentation",
            Name = "PowerPoint / Slides",
            Category = "Work",
            Description = "Slide navigation and presenter shortcuts."
        };
        presentation.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "start", Label = "Start Slideshow", ActionType = "key", Key = "F5" },
            new RemoteActionDefinition { Id = "next_slide", Label = "Next Slide", ActionType = "key", Key = "PAGEDOWN" },
            new RemoteActionDefinition { Id = "prev_slide", Label = "Prev Slide", ActionType = "key", Key = "PAGEUP" },
            new RemoteActionDefinition { Id = "end_show", Label = "End Show", ActionType = "key", Key = "ESCAPE" },
            new RemoteActionDefinition { Id = "black_screen", Label = "Black Screen", ActionType = "key", Key = "B" },
            new RemoteActionDefinition { Id = "white_screen", Label = "White Screen", ActionType = "key", Key = "W" }
        });
        presentation.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_start", Label = "Start (F5)", Icon = "slideshow", ActionId = "start" },
            new RemoteButtonDefinition { Id = "b_prev_slide", Label = "Previous", Icon = "navigate_before", ActionId = "prev_slide" },
            new RemoteButtonDefinition { Id = "b_next_slide", Label = "Next", Icon = "navigate_next", ActionId = "next_slide" },
            new RemoteButtonDefinition { Id = "b_black", Label = "Black (B)", Icon = "dark_mode", ActionId = "black_screen" },
            new RemoteButtonDefinition { Id = "b_white", Label = "White (W)", Icon = "light_mode", ActionId = "white_screen" },
            new RemoteButtonDefinition { Id = "b_end", Label = "Exit (Esc)", Icon = "stop", ActionId = "end_show" }
        });
        _remotes[presentation.Id] = presentation;
    }

    public bool ExecuteAction(RemoteActionDefinition action, out string? errorMessage)
    {
        errorMessage = null;
        try
        {
            switch (action.ActionType.ToLowerInvariant())
            {
                case "key":
                    if (!string.IsNullOrEmpty(action.Key))
                    {
                        var vk = NativeInputSimulator.ResolveKeyVk(action.Key);
                        if (vk != 0)
                        {
                            NativeInputSimulator.Instance.SendVirtualKey(vk, true);
                            Thread.Sleep(10);
                            NativeInputSimulator.Instance.SendVirtualKey(vk, false);
                        }
                        else
                        {
                            NativeInputSimulator.Instance.SendText(action.Key);
                        }
                    }
                    return true;

                case "key_combination":
                    if (!string.IsNullOrEmpty(action.Key))
                    {
                        NativeInputSimulator.Instance.SendKeyCombination(action.Modifiers ?? new(), action.Key);
                    }
                    return true;

                case "media":
                    switch (action.MediaAction?.ToLowerInvariant())
                    {
                        case "play_pause": MediaController.Instance.PlayPause(); break;
                        case "next": MediaController.Instance.NextTrack(); break;
                        case "prev": MediaController.Instance.PreviousTrack(); break;
                        case "stop": MediaController.Instance.Stop(); break;
                    }
                    return true;

                default:
                    errorMessage = $"Unsupported action type: {action.ActionType}";
                    return false;
            }
        }
        catch (Exception ex)
        {
            errorMessage = ex.Message;
            return false;
        }
    }
}
