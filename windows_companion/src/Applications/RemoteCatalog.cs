using System.Text.Json.Serialization;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.SystemControl;

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

        // 2. Spotify Desktop Remote
        var spotify = new RemoteDefinition
        {
            Id = "spotify",
            Name = "Spotify",
            Category = "Media",
            Description = "Desktop music playback, shuffle, volume, and playlist controls."
        };
        spotify.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "play_pause", Label = "Play / Pause", ActionType = "key", Key = "SPACE" },
            new RemoteActionDefinition { Id = "next", Label = "Next Track", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "RIGHT" },
            new RemoteActionDefinition { Id = "prev", Label = "Previous Track", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "LEFT" },
            new RemoteActionDefinition { Id = "vol_up", Label = "Volume Up", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "UP" },
            new RemoteActionDefinition { Id = "vol_down", Label = "Volume Down", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "DOWN" },
            new RemoteActionDefinition { Id = "shuffle", Label = "Toggle Shuffle", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "S" },
            new RemoteActionDefinition { Id = "repeat", Label = "Toggle Repeat", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "R" },
            new RemoteActionDefinition { Id = "like", Label = "Save to Library", ActionType = "key_combination", Modifiers = new() { "alt", "shift" }, Key = "B" },
            new RemoteActionDefinition { Id = "lyrics", Label = "Toggle Lyrics", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "K" },
            new RemoteActionDefinition { Id = "seek_fwd", Label = "Seek +5s", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "RIGHT" },
            new RemoteActionDefinition { Id = "seek_back", Label = "Seek -5s", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "LEFT" },
            new RemoteActionDefinition { Id = "mute", Label = "Mute", ActionType = "media", MediaAction = "mute" }
        });
        spotify.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_sp_prev", Label = "Prev", Icon = "skip_previous", ActionId = "prev" },
            new RemoteButtonDefinition { Id = "b_sp_play", Label = "Play/Pause", Icon = "play_arrow", ActionId = "play_pause", ColorHex = "#1DB954" },
            new RemoteButtonDefinition { Id = "b_sp_next", Label = "Next", Icon = "skip_next", ActionId = "next" },
            new RemoteButtonDefinition { Id = "b_sp_shuffle", Label = "Shuffle", Icon = "shuffle", ActionId = "shuffle" },
            new RemoteButtonDefinition { Id = "b_sp_repeat", Label = "Repeat", Icon = "repeat", ActionId = "repeat" },
            new RemoteButtonDefinition { Id = "b_sp_like", Label = "Like", Icon = "favorite", ActionId = "like", ColorHex = "#1DB954" },
            new RemoteButtonDefinition { Id = "b_sp_vup", Label = "Vol +", Icon = "volume_up", ActionId = "vol_up" },
            new RemoteButtonDefinition { Id = "b_sp_vdown", Label = "Vol -", Icon = "volume_down", ActionId = "vol_down" },
            new RemoteButtonDefinition { Id = "b_sp_mute", Label = "Mute", Icon = "volume_off", ActionId = "mute" },
            new RemoteButtonDefinition { Id = "b_sp_back", Label = "-5s", Icon = "replay_5", ActionId = "seek_back" },
            new RemoteButtonDefinition { Id = "b_sp_fwd", Label = "+5s", Icon = "forward_5", ActionId = "seek_fwd" },
            new RemoteButtonDefinition { Id = "b_sp_lyrics", Label = "Lyrics", Icon = "subtitles", ActionId = "lyrics" }
        });
        _remotes[spotify.Id] = spotify;

        // 3. YouTube Deck
        var youtube = new RemoteDefinition
        {
            Id = "youtube",
            Name = "YouTube",
            Category = "Web",
            Description = "Dedicated playback, 10s seeks, miniplayer, and speed controls."
        };
        youtube.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "play_pause", Label = "Play / Pause", ActionType = "key", Key = "K" },
            new RemoteActionDefinition { Id = "rewind_10", Label = "Rewind 10s", ActionType = "key", Key = "J" },
            new RemoteActionDefinition { Id = "forward_10", Label = "Forward 10s", ActionType = "key", Key = "L" },
            new RemoteActionDefinition { Id = "rewind_5", Label = "Rewind 5s", ActionType = "key", Key = "LEFT" },
            new RemoteActionDefinition { Id = "forward_5", Label = "Forward 5s", ActionType = "key", Key = "RIGHT" },
            new RemoteActionDefinition { Id = "fullscreen", Label = "Fullscreen", ActionType = "key", Key = "F" },
            new RemoteActionDefinition { Id = "theater", Label = "Theater Mode", ActionType = "key", Key = "T" },
            new RemoteActionDefinition { Id = "miniplayer", Label = "Miniplayer", ActionType = "key", Key = "I" },
            new RemoteActionDefinition { Id = "captions", Label = "Closed Captions", ActionType = "key", Key = "C" },
            new RemoteActionDefinition { Id = "mute", Label = "Mute / Unmute", ActionType = "key", Key = "M" },
            new RemoteActionDefinition { Id = "next_video", Label = "Next Video", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "N" },
            new RemoteActionDefinition { Id = "prev_video", Label = "Prev Video", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "P" },
            new RemoteActionDefinition { Id = "speed_up", Label = "Speed Up", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "PERIOD" },
            new RemoteActionDefinition { Id = "slow_down", Label = "Slow Down", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "COMMA" }
        });
        youtube.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_yt_rew10", Label = "-10s", Icon = "replay_10", ActionId = "rewind_10" },
            new RemoteButtonDefinition { Id = "b_yt_play", Label = "Play/Pause", Icon = "play_arrow", ActionId = "play_pause", ColorHex = "#FF0000" },
            new RemoteButtonDefinition { Id = "b_yt_fwd10", Label = "+10s", Icon = "forward_10", ActionId = "forward_10" },
            new RemoteButtonDefinition { Id = "b_yt_prev", Label = "Prev Video", Icon = "skip_previous", ActionId = "prev_video" },
            new RemoteButtonDefinition { Id = "b_yt_next", Label = "Next Video", Icon = "skip_next", ActionId = "next_video" },
            new RemoteButtonDefinition { Id = "b_yt_fs", Label = "Fullscreen", Icon = "fullscreen", ActionId = "fullscreen" },
            new RemoteButtonDefinition { Id = "b_yt_theater", Label = "Theater", Icon = "tv", ActionId = "theater" },
            new RemoteButtonDefinition { Id = "b_yt_mini", Label = "Miniplayer", Icon = "branding_watermark", ActionId = "miniplayer" },
            new RemoteButtonDefinition { Id = "b_yt_cc", Label = "Captions", Icon = "closed_caption", ActionId = "captions" },
            new RemoteButtonDefinition { Id = "b_yt_mute", Label = "Mute", Icon = "volume_off", ActionId = "mute" },
            new RemoteButtonDefinition { Id = "b_yt_slow", Label = "Slower", Icon = "speed", ActionId = "slow_down" },
            new RemoteButtonDefinition { Id = "b_yt_fast", Label = "Faster", Icon = "speed", ActionId = "speed_up" }
        });
        _remotes[youtube.Id] = youtube;

        // 4. Netflix / Streaming Remote
        var netflix = new RemoteDefinition
        {
            Id = "netflix",
            Name = "Netflix / Streaming",
            Category = "Media",
            Description = "Streaming player controls for Netflix, Disney+, and Prime Video."
        };
        netflix.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "play_pause", Label = "Play / Pause", ActionType = "key", Key = "SPACE" },
            new RemoteActionDefinition { Id = "rewind_10", Label = "Rewind 10s", ActionType = "key", Key = "LEFT" },
            new RemoteActionDefinition { Id = "forward_10", Label = "Forward 10s", ActionType = "key", Key = "RIGHT" },
            new RemoteActionDefinition { Id = "fullscreen", Label = "Fullscreen", ActionType = "key", Key = "F" },
            new RemoteActionDefinition { Id = "audio_subtitles", Label = "Audio & Subtitles", ActionType = "key", Key = "S" },
            new RemoteActionDefinition { Id = "mute", Label = "Mute", ActionType = "key", Key = "M" },
            new RemoteActionDefinition { Id = "vol_up", Label = "Volume Up", ActionType = "key", Key = "UP" },
            new RemoteActionDefinition { Id = "vol_down", Label = "Volume Down", ActionType = "key", Key = "DOWN" },
            new RemoteActionDefinition { Id = "skip_intro", Label = "Skip Intro / Next", ActionType = "key", Key = "ENTER" }
        });
        netflix.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_nf_rew", Label = "-10s", Icon = "replay_10", ActionId = "rewind_10" },
            new RemoteButtonDefinition { Id = "b_nf_play", Label = "Play/Pause", Icon = "play_arrow", ActionId = "play_pause", ColorHex = "#E50914" },
            new RemoteButtonDefinition { Id = "b_nf_fwd", Label = "+10s", Icon = "forward_10", ActionId = "forward_10" },
            new RemoteButtonDefinition { Id = "b_nf_skip", Label = "Skip Intro", Icon = "fast_forward", ActionId = "skip_intro" },
            new RemoteButtonDefinition { Id = "b_nf_fs", Label = "Fullscreen", Icon = "fullscreen", ActionId = "fullscreen" },
            new RemoteButtonDefinition { Id = "b_nf_sub", Label = "Audio & Sub", Icon = "subtitles", ActionId = "audio_subtitles" },
            new RemoteButtonDefinition { Id = "b_nf_vup", Label = "Vol +", Icon = "volume_up", ActionId = "vol_up" },
            new RemoteButtonDefinition { Id = "b_nf_vdown", Label = "Vol -", Icon = "volume_down", ActionId = "vol_down" },
            new RemoteButtonDefinition { Id = "b_nf_mute", Label = "Mute", Icon = "volume_off", ActionId = "mute" }
        });
        _remotes[netflix.Id] = netflix;

        // 5. Browser Remote
        var browser = new RemoteDefinition
        {
            Id = "browser",
            Name = "Web Browser",
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
            new RemoteActionDefinition { Id = "fs", Label = "Fullscreen", ActionType = "key", Key = "F11" },
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

        // 6. Discord Remote
        var discord = new RemoteDefinition
        {
            Id = "discord",
            Name = "Discord",
            Category = "Social",
            Description = "Voice mute, deafen, camera, server navigation, and call controls."
        };
        discord.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "mute_mic", Label = "Toggle Mute", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "M" },
            new RemoteActionDefinition { Id = "deafen", Label = "Toggle Deafen", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "D" },
            new RemoteActionDefinition { Id = "toggle_camera", Label = "Toggle Camera", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "V" },
            new RemoteActionDefinition { Id = "answer_call", Label = "Answer Call", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "ENTER" },
            new RemoteActionDefinition { Id = "decline_call", Label = "Decline Call", ActionType = "key", Key = "ESCAPE" },
            new RemoteActionDefinition { Id = "quick_switcher", Label = "Quick Switcher", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "K" },
            new RemoteActionDefinition { Id = "prev_server", Label = "Prev Server", ActionType = "key_combination", Modifiers = new() { "ctrl", "alt" }, Key = "UP" },
            new RemoteActionDefinition { Id = "next_server", Label = "Next Server", ActionType = "key_combination", Modifiers = new() { "ctrl", "alt" }, Key = "DOWN" },
            new RemoteActionDefinition { Id = "prev_channel", Label = "Prev Channel", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "UP" },
            new RemoteActionDefinition { Id = "next_channel", Label = "Next Channel", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "DOWN" },
            new RemoteActionDefinition { Id = "mark_read", Label = "Mark Channel Read", ActionType = "key", Key = "ESCAPE" },
            new RemoteActionDefinition { Id = "pins", Label = "Pinned Messages", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "P" }
        });
        discord.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_dc_mute", Label = "Mute Mic", Icon = "mic_off", ActionId = "mute_mic", ColorHex = "#ED4245" },
            new RemoteButtonDefinition { Id = "b_dc_deafen", Label = "Deafen", Icon = "headset_off", ActionId = "deafen", ColorHex = "#ED4245" },
            new RemoteButtonDefinition { Id = "b_dc_cam", Label = "Camera", Icon = "videocam", ActionId = "toggle_camera", ColorHex = "#5865F2" },
            new RemoteButtonDefinition { Id = "b_dc_answer", Label = "Answer", Icon = "call", ActionId = "answer_call", ColorHex = "#57F287" },
            new RemoteButtonDefinition { Id = "b_dc_decline", Label = "Decline", Icon = "call_end", ActionId = "decline_call", ColorHex = "#ED4245" },
            new RemoteButtonDefinition { Id = "b_dc_quick", Label = "Quick Find", Icon = "search", ActionId = "quick_switcher" },
            new RemoteButtonDefinition { Id = "b_dc_psrv", Label = "Prev Server", Icon = "keyboard_arrow_up", ActionId = "prev_server" },
            new RemoteButtonDefinition { Id = "b_dc_nsrv", Label = "Next Server", Icon = "keyboard_arrow_down", ActionId = "next_server" },
            new RemoteButtonDefinition { Id = "b_dc_pchan", Label = "Prev Channel", Icon = "arrow_back", ActionId = "prev_channel" },
            new RemoteButtonDefinition { Id = "b_dc_nchan", Label = "Next Channel", Icon = "arrow_forward", ActionId = "next_channel" },
            new RemoteButtonDefinition { Id = "b_dc_read", Label = "Mark Read", Icon = "done_all", ActionId = "mark_read" },
            new RemoteButtonDefinition { Id = "b_dc_pins", Label = "Pins", Icon = "push_pin", ActionId = "pins" }
        });
        _remotes[discord.Id] = discord;

        // 7. Visual Studio Code Remote
        var vscode = new RemoteDefinition
        {
            Id = "vscode",
            Name = "VS Code",
            Category = "Developer",
            Description = "Command palette, terminal, sidebar, debugging, search, and formatting."
        };
        vscode.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "command_palette", Label = "Command Palette", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "P" },
            new RemoteActionDefinition { Id = "quick_open", Label = "Quick Open File", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "P" },
            new RemoteActionDefinition { Id = "toggle_terminal", Label = "Toggle Terminal", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "BACKTICK" },
            new RemoteActionDefinition { Id = "toggle_sidebar", Label = "Toggle Sidebar", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "B" },
            new RemoteActionDefinition { Id = "find_files", Label = "Find in Files", ActionType = "key_combination", Modifiers = new() { "ctrl", "shift" }, Key = "F" },
            new RemoteActionDefinition { Id = "save_file", Label = "Save File", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "S" },
            new RemoteActionDefinition { Id = "format_doc", Label = "Format Document", ActionType = "key_combination", Modifiers = new() { "shift", "alt" }, Key = "F" },
            new RemoteActionDefinition { Id = "start_debug", Label = "Start Debugging", ActionType = "key", Key = "F5" },
            new RemoteActionDefinition { Id = "stop_debug", Label = "Stop Debugging", ActionType = "key_combination", Modifiers = new() { "shift" }, Key = "F5" },
            new RemoteActionDefinition { Id = "step_over", Label = "Step Over", ActionType = "key", Key = "F10" },
            new RemoteActionDefinition { Id = "step_into", Label = "Step Into", ActionType = "key", Key = "F11" },
            new RemoteActionDefinition { Id = "split_editor", Label = "Split Editor", ActionType = "key_combination", Modifiers = new() { "ctrl" }, Key = "BACKSLASH" }
        });
        vscode.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_vsc_pal", Label = "Palette", Icon = "terminal", ActionId = "command_palette", ColorHex = "#007ACC" },
            new RemoteButtonDefinition { Id = "b_vsc_open", Label = "Quick Open", Icon = "folder", ActionId = "quick_open" },
            new RemoteButtonDefinition { Id = "b_vsc_term", Label = "Terminal", Icon = "code", ActionId = "toggle_terminal" },
            new RemoteButtonDefinition { Id = "b_vsc_side", Label = "Sidebar", Icon = "vertical_split", ActionId = "toggle_sidebar" },
            new RemoteButtonDefinition { Id = "b_vsc_find", Label = "Search", Icon = "search", ActionId = "find_files" },
            new RemoteButtonDefinition { Id = "b_vsc_save", Label = "Save", Icon = "save", ActionId = "save_file" },
            new RemoteButtonDefinition { Id = "b_vsc_fmt", Label = "Format", Icon = "refresh", ActionId = "format_doc" },
            new RemoteButtonDefinition { Id = "b_vsc_f5", Label = "Debug (F5)", Icon = "play_arrow", ActionId = "start_debug", ColorHex = "#4EC9B0" },
            new RemoteButtonDefinition { Id = "b_vsc_stop", Label = "Stop (⇧F5)", Icon = "stop", ActionId = "stop_debug", ColorHex = "#F14C4C" },
            new RemoteButtonDefinition { Id = "b_vsc_f10", Label = "Step Over", Icon = "arrow_forward", ActionId = "step_over" },
            new RemoteButtonDefinition { Id = "b_vsc_f11", Label = "Step Into", Icon = "arrow_downward", ActionId = "step_into" },
            new RemoteButtonDefinition { Id = "b_vsc_split", Label = "Split View", Icon = "dashboard", ActionId = "split_editor" }
        });
        _remotes[vscode.Id] = vscode;

        // 8. OBS Studio Remote
        var obs = new RemoteDefinition
        {
            Id = "obs",
            Name = "OBS Studio",
            Category = "Streaming",
            Description = "Broadcasting shortcuts for streaming, recording, scene switching & replay buffer."
        };
        obs.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "stream_toggle", Label = "Stream Toggle", ActionType = "key", Key = "F9" },
            new RemoteActionDefinition { Id = "record_toggle", Label = "Record Toggle", ActionType = "key", Key = "F10" },
            new RemoteActionDefinition { Id = "record_pause", Label = "Pause Recording", ActionType = "key", Key = "F11" },
            new RemoteActionDefinition { Id = "mute_mic", Label = "Mute / Unmute Mic", ActionType = "key", Key = "F7" },
            new RemoteActionDefinition { Id = "mute_desktop", Label = "Mute / Unmute Desktop", ActionType = "key", Key = "F6" },
            new RemoteActionDefinition { Id = "replay_buffer", Label = "Save Replay Buffer", ActionType = "key", Key = "F8" },
            new RemoteActionDefinition { Id = "prev_scene", Label = "Previous Scene", ActionType = "key", Key = "PAGEUP" },
            new RemoteActionDefinition { Id = "next_scene", Label = "Next Scene", ActionType = "key", Key = "PAGEDOWN" },
            new RemoteActionDefinition { Id = "studio_transition", Label = "Studio Transition", ActionType = "key", Key = "SPACE" }
        });
        obs.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_obs_stream", Label = "Stream (F9)", Icon = "podcasts", ActionId = "stream_toggle", ColorHex = "#9B59B6" },
            new RemoteButtonDefinition { Id = "b_obs_rec", Label = "Record (F10)", Icon = "fiber_manual_record", ActionId = "record_toggle", ColorHex = "#E74C3C" },
            new RemoteButtonDefinition { Id = "b_obs_pause", Label = "Pause (F11)", Icon = "pause", ActionId = "record_pause" },
            new RemoteButtonDefinition { Id = "b_obs_mic", Label = "Mute Mic (F7)", Icon = "mic_off", ActionId = "mute_mic", ColorHex = "#E67E22" },
            new RemoteButtonDefinition { Id = "b_obs_desk", Label = "Mute PC (F6)", Icon = "volume_off", ActionId = "mute_desktop" },
            new RemoteButtonDefinition { Id = "b_obs_replay", Label = "Replay (F8)", Icon = "replay", ActionId = "replay_buffer", ColorHex = "#3498DB" },
            new RemoteButtonDefinition { Id = "b_obs_pscene", Label = "Prev Scene", Icon = "navigate_before", ActionId = "prev_scene" },
            new RemoteButtonDefinition { Id = "b_obs_nscene", Label = "Next Scene", Icon = "navigate_next", ActionId = "next_scene" },
            new RemoteButtonDefinition { Id = "b_obs_cut", Label = "Transition", Icon = "videocam", ActionId = "studio_transition" }
        });
        _remotes[obs.Id] = obs;

        // 9. Windows Manager Remote
        var windows = new RemoteDefinition
        {
            Id = "windows",
            Name = "Windows Manager",
            Category = "System",
            Description = "Task view, show desktop, window snapping, screenshot snip tool, and explorer."
        };
        windows.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "task_view", Label = "Task View", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "TAB" },
            new RemoteActionDefinition { Id = "show_desktop", Label = "Show Desktop", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "D" },
            new RemoteActionDefinition { Id = "snip_tool", Label = "Snip Tool (Screenshot)", ActionType = "key_combination", Modifiers = new() { "win", "shift" }, Key = "S" },
            new RemoteActionDefinition { Id = "open_explorer", Label = "File Explorer", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "E" },
            new RemoteActionDefinition { Id = "open_settings", Label = "Windows Settings", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "I" },
            new RemoteActionDefinition { Id = "lock_pc", Label = "Lock Workstation", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "L" },
            new RemoteActionDefinition { Id = "snap_left", Label = "Snap Left", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "LEFT" },
            new RemoteActionDefinition { Id = "snap_right", Label = "Snap Right", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "RIGHT" },
            new RemoteActionDefinition { Id = "snap_max", Label = "Maximize Window", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "UP" },
            new RemoteActionDefinition { Id = "snap_min", Label = "Minimize Window", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "DOWN" },
            new RemoteActionDefinition { Id = "action_center", Label = "Action Center", ActionType = "key_combination", Modifiers = new() { "win" }, Key = "A" },
            new RemoteActionDefinition { Id = "close_window", Label = "Close Window", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "F4" }
        });
        windows.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_win_task", Label = "Task View", Icon = "dashboard", ActionId = "task_view", ColorHex = "#0078D7" },
            new RemoteButtonDefinition { Id = "b_win_desk", Label = "Desktop", Icon = "desktop_windows", ActionId = "show_desktop" },
            new RemoteButtonDefinition { Id = "b_win_snip", Label = "Snip Tool", Icon = "camera_alt", ActionId = "snip_tool", ColorHex = "#0078D7" },
            new RemoteButtonDefinition { Id = "b_win_exp", Label = "Explorer", Icon = "folder", ActionId = "open_explorer" },
            new RemoteButtonDefinition { Id = "b_win_set", Label = "Settings", Icon = "settings", ActionId = "open_settings" },
            new RemoteButtonDefinition { Id = "b_win_lock", Label = "Lock PC", Icon = "lock", ActionId = "lock_pc", ColorHex = "#E74C3C" },
            new RemoteButtonDefinition { Id = "b_win_sleft", Label = "Snap Left", Icon = "arrow_back", ActionId = "snap_left" },
            new RemoteButtonDefinition { Id = "b_win_sright", Label = "Snap Right", Icon = "arrow_forward", ActionId = "snap_right" },
            new RemoteButtonDefinition { Id = "b_win_max", Label = "Maximize", Icon = "crop_square", ActionId = "snap_max" },
            new RemoteButtonDefinition { Id = "b_win_min", Label = "Minimize", Icon = "remove", ActionId = "snap_min" },
            new RemoteButtonDefinition { Id = "b_win_act", Label = "Action Ctr", Icon = "notifications", ActionId = "action_center" },
            new RemoteButtonDefinition { Id = "b_win_close", Label = "Close App", Icon = "close", ActionId = "close_window", ColorHex = "#E74C3C" }
        });
        _remotes[windows.Id] = windows;

        // 10. Zoom & Video Meetings Remote
        var meetings = new RemoteDefinition
        {
            Id = "meetings",
            Name = "Video Meetings / Zoom",
            Category = "Social",
            Description = "Meeting controls for Zoom, Google Meet & Microsoft Teams."
        };
        meetings.Actions.AddRange(new[]
        {
            new RemoteActionDefinition { Id = "toggle_mic", Label = "Mute / Unmute Mic", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "A" },
            new RemoteActionDefinition { Id = "toggle_video", Label = "Start / Stop Video", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "V" },
            new RemoteActionDefinition { Id = "share_screen", Label = "Share Screen", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "S" },
            new RemoteActionDefinition { Id = "raise_hand", Label = "Raise / Lower Hand", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "Y" },
            new RemoteActionDefinition { Id = "chat_panel", Label = "Meeting Chat", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "H" },
            new RemoteActionDefinition { Id = "participants", Label = "Participants", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "U" },
            new RemoteActionDefinition { Id = "full_screen", Label = "Toggle Fullscreen", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "F" },
            new RemoteActionDefinition { Id = "leave_call", Label = "Leave Meeting", ActionType = "key_combination", Modifiers = new() { "alt" }, Key = "Q" }
        });
        meetings.Buttons.AddRange(new[]
        {
            new RemoteButtonDefinition { Id = "b_meet_mic", Label = "Mic (Alt+A)", Icon = "mic_off", ActionId = "toggle_mic", ColorHex = "#E74C3C" },
            new RemoteButtonDefinition { Id = "b_meet_cam", Label = "Video (Alt+V)", Icon = "videocam", ActionId = "toggle_video", ColorHex = "#2D8CFF" },
            new RemoteButtonDefinition { Id = "b_meet_share", Label = "Share Screen", Icon = "screen_share", ActionId = "share_screen", ColorHex = "#27AE60" },
            new RemoteButtonDefinition { Id = "b_meet_hand", Label = "Raise Hand", Icon = "pan_tool", ActionId = "raise_hand", ColorHex = "#F39C12" },
            new RemoteButtonDefinition { Id = "b_meet_chat", Label = "Chat", Icon = "chat", ActionId = "chat_panel" },
            new RemoteButtonDefinition { Id = "b_meet_people", Label = "People", Icon = "people", ActionId = "participants" },
            new RemoteButtonDefinition { Id = "b_meet_fs", Label = "Fullscreen", Icon = "fullscreen", ActionId = "full_screen" },
            new RemoteButtonDefinition { Id = "b_meet_leave", Label = "Leave Call", Icon = "call_end", ActionId = "leave_call", ColorHex = "#C0392B" }
        });
        _remotes[meetings.Id] = meetings;

        // 11. Presentation Remote (PowerPoint / Keynote / Slides)
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
                        case "vol_up": MediaController.Instance.VolumeUp(); break;
                        case "vol_down": MediaController.Instance.VolumeDown(); break;
                        case "mute": MediaController.Instance.VolumeMute(); break;
                        case "seek_fwd": MediaController.Instance.SeekForward(); break;
                        case "seek_back": MediaController.Instance.SeekBackward(); break;
                    }
                    return true;

                case "system":
                    switch (action.Key?.ToLowerInvariant())
                    {
                        case "lock": SystemController.Instance.LockPC(); break;
                        case "sleep": SystemController.Instance.SleepPC(); break;
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
