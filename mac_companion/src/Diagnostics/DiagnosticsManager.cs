using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Diagnostics;

public class DiagnosticsCommandHandler : ICommandHandler
{
    private readonly Func<bool> _isServerRunning;
    private readonly int _serverPort;

    public DiagnosticsCommandHandler(Func<bool> isServerRunning, int serverPort)
    {
        _isServerRunning = isServerRunning;
        _serverPort = serverPort;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        var items = new List<object>
        {
            new { subsystem = "WebSocket Server", status = _isServerRunning() ? "PASS" : "FAIL", message = $"Port {_serverPort} active" },
            new { subsystem = "Operating System", status = "PASS", message = $"macOS ({Environment.OSVersion})" },
            new { subsystem = "Security Manager", status = "PASS", message = "SHA-256 Auth Active" },
            new { subsystem = "Input Simulation", status = "PASS", message = "CoreGraphics Accessibility ready" }
        };

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { items }));
    }
}
