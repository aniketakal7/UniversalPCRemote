using System.Collections.Concurrent;

namespace UniversalPCRemote.Companion.Logging;

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

        // Also write to standard debug console
        Console.WriteLine($"[{entry.Timestamp:HH:mm:ss.fff}] [{entry.Level.ToString().ToUpperInvariant()}] [{entry.Component}] {entry.Message}{(string.IsNullOrEmpty(entry.RequestId) ? "" : $" (Req: {entry.RequestId})")}");

        try
        {
            LogEmitted?.Invoke(entry);
        }
        catch
        {
            // Logging should never crash the application
        }
    }

    public void Debug(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Debug, component, message, requestId, command, connId);

    public void Info(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Info, component, message, requestId, command, connId);

    public void Warn(string component, string message, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Warning, component, message, requestId, command, connId);

    public void Error(string component, string message, Exception? ex = null, string? requestId = null, string? command = null, string? connId = null)
        => Log(LogLevel.Error, component, message, requestId, command, connId, ex?.ToString());

    public IReadOnlyList<LogEntry> GetRecentLogs() => _logs.ToArray();
}
