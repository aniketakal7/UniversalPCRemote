using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Serialization;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.SystemControl;

namespace UniversalPCRemote.Companion.Macros;

public class MacroStepDefinition
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty; // "delay", "key_combination", "mouse_click", "media", "system", "open_app"

    [JsonPropertyName("payload")]
    public JsonElement? Payload { get; set; }
}

public class MacroDefinition
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("steps")]
    public List<MacroStepDefinition> Steps { get; set; } = new();
}

public class MacroEngine
{
    private static readonly Lazy<MacroEngine> _instance = new(() => new MacroEngine());
    public static MacroEngine Instance => _instance.Value;

    private readonly Dictionary<string, MacroDefinition> _macros = new(StringComparer.OrdinalIgnoreCase);

    // Strict allowlist for open_app
    private static readonly HashSet<string> AllowedApplications = new(StringComparer.OrdinalIgnoreCase)
    {
        "notepad", "calc", "mspaint", "explorer", "taskmgr", "cmd"
    };

    public MacroEngine()
    {
        InitializeDefaultMacros();
    }

    public IReadOnlyList<MacroDefinition> GetAllMacros() => _macros.Values.ToList();

    public MacroDefinition? GetMacro(string id) => _macros.TryGetValue(id, out var m) ? m : null;

    private void InitializeDefaultMacros()
    {
        // 1. Quick Notepad Notes Macro
        _macros["quick_notes"] = new MacroDefinition
        {
            Id = "quick_notes",
            Name = "Open Quick Scratchpad",
            Description = "Launches Notepad and adds a timestamp header.",
            Steps = new List<MacroStepDefinition>
            {
                new() { Type = "open_app", Payload = JsonSerializer.SerializeToElement(new { appName = "notepad" }) },
                new() { Type = "delay", Payload = JsonSerializer.SerializeToElement(new { ms = 600 }) },
                new() { Type = "type_text", Payload = JsonSerializer.SerializeToElement(new { text = $"[Universal Remote Note - {DateTime.Now:yyyy-MM-dd HH:mm}]\r\n" }) }
            }
        };

        // 2. Lock & Mute Macro
        _macros["lock_and_mute"] = new MacroDefinition
        {
            Id = "lock_and_mute",
            Name = "Away / Privacy",
            Description = "Mutes volume and locks Windows workstation immediately.",
            Steps = new List<MacroStepDefinition>
            {
                new() { Type = "media", Payload = JsonSerializer.SerializeToElement(new { action = "mute" }) },
                new() { Type = "delay", Payload = JsonSerializer.SerializeToElement(new { ms = 100 }) },
                new() { Type = "system", Payload = JsonSerializer.SerializeToElement(new { action = "lock" }) }
            }
        };

        // 3. Show Desktop Macro
        _macros["show_desktop"] = new MacroDefinition
        {
            Id = "show_desktop",
            Name = "Show Desktop (Win+D)",
            Description = "Minimizes all windows to display desktop.",
            Steps = new List<MacroStepDefinition>
            {
                new() { Type = "key_combination", Payload = JsonSerializer.SerializeToElement(new { modifiers = new[] { "win" }, key = "D" }) }
            }
        };
    }

    public async Task<bool> ExecuteMacroAsync(MacroDefinition macro, CancellationToken cancellationToken = default)
    {
        AppLogger.Instance.Info("Macro", $"Executing macro '{macro.Name}' ({macro.Id}) with {macro.Steps.Count} steps.");

        foreach (var step in macro.Steps)
        {
            if (cancellationToken.IsCancellationRequested) return false;
            await ExecuteStepAsync(step, cancellationToken);
        }

        return true;
    }

    public async Task ExecuteStepAsync(MacroStepDefinition step, CancellationToken cancellationToken = default)
    {
        switch (step.Type.ToLowerInvariant())
        {
            case "delay":
                int ms = 200;
                if (step.Payload?.TryGetProperty("ms", out var msProp) == true) ms = Math.Clamp(msProp.GetInt32(), 10, 10000);
                await Task.Delay(ms, cancellationToken);
                break;

            case "key_combination":
                if (step.Payload?.TryGetProperty("key", out var kProp) == true)
                {
                    var key = kProp.GetString() ?? "";
                    var mods = new List<string>();
                    if (step.Payload.Value.TryGetProperty("modifiers", out var mProp) && mProp.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var m in mProp.EnumerateArray())
                        {
                            var s = m.GetString();
                            if (!string.IsNullOrEmpty(s)) mods.Add(s);
                        }
                    }
                    NativeInputSimulator.Instance.SendKeyCombination(mods, key);
                }
                break;

            case "type_text":
                if (step.Payload?.TryGetProperty("text", out var tProp) == true)
                {
                    NativeInputSimulator.Instance.SendText(tProp.GetString() ?? "");
                }
                break;

            case "mouse_click":
                string button = "left";
                int clicks = 1;
                if (step.Payload?.TryGetProperty("button", out var bProp) == true) button = bProp.GetString() ?? "left";
                if (step.Payload?.TryGetProperty("clicks", out var cProp) == true) clicks = cProp.GetInt32();
                NativeInputSimulator.Instance.MouseClick(button, clicks);
                break;

            case "media":
                var action = step.Payload?.TryGetProperty("action", out var aProp) == true ? aProp.GetString() : "play_pause";
                switch (action?.ToLowerInvariant())
                {
                    case "play_pause": MediaController.Instance.PlayPause(); break;
                    case "next": MediaController.Instance.NextTrack(); break;
                    case "prev": MediaController.Instance.PreviousTrack(); break;
                    case "stop": MediaController.Instance.Stop(); break;
                    case "mute": MediaController.Instance.VolumeMute(); break;
                }
                break;

            case "system":
                var sysAction = step.Payload?.TryGetProperty("action", out var saProp) == true ? saProp.GetString() : "lock";
                switch (sysAction?.ToLowerInvariant())
                {
                    case "lock": SystemController.Instance.LockPC(); break;
                    case "sleep": SystemController.Instance.SleepPC(); break;
                }
                break;

            case "open_app":
                if (step.Payload?.TryGetProperty("appName", out var appProp) == true)
                {
                    var appName = appProp.GetString() ?? "";
                    if (AllowedApplications.Contains(appName))
                    {
                        Process.Start(new ProcessStartInfo(appName) { UseShellExecute = true });
                    }
                    else
                    {
                        AppLogger.Instance.Warn("Macro", $"Blocked unauthorized open_app execution for '{appName}'");
                    }
                }
                break;

            default:
                AppLogger.Instance.Warn("Macro", $"Unsupported macro step type: '{step.Type}'");
                break;
        }
    }
}
