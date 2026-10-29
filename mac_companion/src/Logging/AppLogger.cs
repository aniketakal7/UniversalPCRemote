using System.Collections.Concurrent;

namespace UniversalPCRemote.Mac.Logging;

public enum LogLevel
{
    Debug,
    Info,
    Warning,
    Error
}

public record LogEntry(
    DateTime Timestamp,
    LogLevel Level,
    string Component,
    string Message,
    string? RequestId = null,
    string? CommandType = null,
    string? ConnectionId = null,
    string? ErrorDetails = null
);

public class AppLogger
{
    private static readonly Lazy<AppLogger> _instance = new(() => new AppLogger());
    public static AppLogger Instance => _instance.Value;

    private readonly ConcurrentQueue<LogEntry> _logs = new();
    private const int MaxLogCapacity = 1000;

    public event Action<LogEntry>? LogEmitted;

    public void Log(
        LogLevel level,
        string component,
        string message,
        string? requestId = null,
        string? commandType = null,
        string? connectionId = null,
        string? errorDetails = null)
    {
        var entry = new LogEntry(
            DateTime.Now,
            level,
            component,
            message,
            requestId,
            commandType,
            connectionId,
            errorDetails
        );

        _logs.Enqueue(entry);
        while (_logs.Count > MaxLogCapacity && _logs.TryDequeue(out _)) { }

        var color = level switch
        {
            LogLevel.Error => ConsoleColor.Red,
            LogLevel.Warning => ConsoleColor.Yellow,
            LogLevel.Info => ConsoleColor.Cyan,
            _ => ConsoleColor.Gray
        };

        var logLine = $"[{entry.Timestamp:HH:mm:ss}] [{entry.Level.ToString().ToUpperInvariant()}] [{entry.Component}] {entry.Message}{(string.IsNullOrEmpty(entry.ErrorDetails) ? "" : $" ({entry.ErrorDetails})")}";
        
        lock (Console.Out)
        {
            var prev = Console.ForegroundColor;
            Console.ForegroundColor = color;
            Console.WriteLine(logLine);
            Console.ForegroundColor = prev;
        }

        try
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var logDir = Path.Combine(home, ".universalpcremote");
            Directory.CreateDirectory(logDir);
            File.AppendAllText(Path.Combine(logDir, "mac_companion.log"), logLine + Environment.NewLine);
        }
        catch { }

        try
        {
            LogEmitted?.Invoke(entry);
        }
        catch { }
    }

    public void Debug(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Debug, component, message, requestId, command, connId);

    public void Info(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Info, component, message, requestId, command, connId);

    public void Warn(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Warning, component, message, requestId, command, connId);

    public void Error(string component, string message, Exception? ex = null, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Error, component, message, requestId, command, connId, ex?.Message);

    public IReadOnlyList<LogEntry> GetRecentLogs() => _logs.ToArray();
}
