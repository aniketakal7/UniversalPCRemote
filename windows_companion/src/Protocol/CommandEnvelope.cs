using System.Text.Json;
using System.Text.Json.Serialization;

namespace UniversalPCRemote.Companion.Protocol;

public class CommandEnvelope
{
    [JsonPropertyName("version")]
    public int Version { get; set; } = 1;

    [JsonPropertyName("requestId")]
    public string RequestId { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("timestamp")]
    public long Timestamp { get; set; }

    [JsonPropertyName("payload")]
    public JsonElement? Payload { get; set; }

    public bool IsValid(out string? validationError)
    {
        if (Version != 1)
        {
            validationError = $"Unsupported protocol version: {Version}. Expected version: 1";
            return false;
        }

        if (string.IsNullOrWhiteSpace(RequestId))
        {
            validationError = "Missing or empty requestId.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(Type))
        {
            validationError = "Missing or empty command type.";
            return false;
        }

        validationError = null;
        return true;
    }
}

public class ResponseEnvelope
{
    [JsonPropertyName("version")]
    public int Version { get; set; } = 1;

    [JsonPropertyName("requestId")]
    public string RequestId { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("data")]
    public object? Data { get; set; }

    [JsonPropertyName("error")]
    public ErrorPayload? Error { get; set; }

    public static ResponseEnvelope CreateSuccess(string requestId, string type, object? data = null)
    {
        return new ResponseEnvelope
        {
            Version = 1,
            RequestId = requestId,
            Type = type,
            Success = true,
            Data = data,
            Error = null
        };
    }

    public static ResponseEnvelope CreateError(string requestId, string type, string code, string message)
    {
        return new ResponseEnvelope
        {
            Version = 1,
            RequestId = requestId,
            Type = type,
            Success = false,
            Data = null,
            Error = new ErrorPayload
            {
                Code = code,
                Message = message
            }
        };
    }
}

public class ErrorPayload
{
    [JsonPropertyName("code")]
    public string Code { get; set; } = string.Empty;

    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;
}
