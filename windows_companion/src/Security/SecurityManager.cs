using System.Security.Cryptography;
using System.Text.Json;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Protocol;

namespace UniversalPCRemote.Companion.Security;

public record TrustedDeviceRecord(
    string DeviceId,
    string DeviceName,
    string TokenHash,
    DateTime PairedAt,
    DateTime LastSeen
);

public class PairingRequestInfo
{
    public string Pin { get; }
    public string DeviceId { get; }
    public string DeviceName { get; }
    public DateTime ExpiresAt { get; }
    public int FailedAttempts { get; set; }

    public PairingRequestInfo(string pin, string deviceId, string deviceName, TimeSpan validity)
    {
        Pin = pin;
        DeviceId = deviceId;
        DeviceName = deviceName;
        ExpiresAt = DateTime.UtcNow.Add(validity);
        FailedAttempts = 0;
    }

    public bool IsExpired => DateTime.UtcNow > ExpiresAt;
}

public class SecurityManager
{
    private static readonly Lazy<SecurityManager> _instance = new(() => new SecurityManager());
    public static SecurityManager Instance => _instance.Value;

    private readonly object _lock = new();
    private readonly Dictionary<string, TrustedDeviceRecord> _trustedDevices = new();
    private readonly string _storageFilePath;
    // A pairing request belongs to a device, not to the server globally.  The
    // previous single-slot implementation caused a second phone to invalidate
    // the first phone's PIN.
    private readonly Dictionary<string, PairingRequestInfo> _activePairings = new();

    public event Action<string, string, string>? PairingCodeGenerated; // deviceId, pin, deviceName
    public event Action<string>? PairingCodeExpired; // deviceId
    public event Action<TrustedDeviceRecord>? DevicePaired;
    public event Action<string>? DeviceRevoked;

    public string? CurrentPairingPin => GetActivePairings().FirstOrDefault()?.Pin;

    public SecurityManager()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var dir = Path.Combine(appData, "UniversalPCRemote");
        Directory.CreateDirectory(dir);
        _storageFilePath = Path.Combine(dir, "trusted_devices.json");

        LoadTrustedDevices();
    }

    public bool IsCommandAllowedUnauthenticated(string commandType)
    {
        return commandType switch
        {
            CommandTypes.AuthPairRequest => true,
            CommandTypes.AuthPairVerify => true,
            CommandTypes.AuthAuthenticate => true,
            CommandTypes.SessionPing => true,
            _ => false
        };
    }

    public string InitiatePairing(string deviceId, string deviceName)
    {
        PairingRequestInfo request;
        lock (_lock)
        {
            // Generate a secure 6-digit random PIN
            var randomBytes = new byte[4];
            RandomNumberGenerator.Fill(randomBytes);
            var pinNum = (BitConverter.ToUInt32(randomBytes, 0) % 900000) + 100000;
            var pin = pinNum.ToString("D6");

            request = new PairingRequestInfo(pin, deviceId, deviceName, TimeSpan.FromSeconds(120));
            _activePairings[deviceId] = request;
        }

        AppLogger.Instance.Info("Security", $"Pairing PIN generated for device '{deviceName}' ({deviceId}). Expires in 120s.");
        PairingCodeGenerated?.Invoke(deviceId, request.Pin, deviceName);
        _ = ExpirePairingAsync(deviceId, request);
        return request.Pin;
    }

    public bool VerifyPairing(string deviceId, string pin, out string? authToken, out string? errorMessage)
    {
        var pairingExpired = false;
        var pairedRecord = default(TrustedDeviceRecord);
        var paired = false;
        lock (_lock)
        {
            authToken = null;
            errorMessage = null;

            if (!_activePairings.TryGetValue(deviceId, out var activePairing) || activePairing.IsExpired)
            {
                _activePairings.Remove(deviceId);
                pairingExpired = true;
                errorMessage = "Pairing session has expired or was not initiated. Please request a new pairing code.";
            }
            else if (activePairing.FailedAttempts >= 5)
            {
                _activePairings.Remove(deviceId);
                pairingExpired = true;
                errorMessage = "Too many failed attempts. Pairing cancelled for security.";
            }
            else if (!string.Equals(activePairing.Pin, pin.Trim(), StringComparison.Ordinal))
            {
                activePairing.FailedAttempts++;
                errorMessage = "Invalid pairing code. Please check the code displayed on your PC screen.";
            }
            else
            {
                // PIN is correct! Generate a high-entropy auth token.
                var tokenBytes = new byte[32];
                RandomNumberGenerator.Fill(tokenBytes);
                authToken = Convert.ToHexString(tokenBytes).ToLowerInvariant();

                pairedRecord = new TrustedDeviceRecord(
                    deviceId,
                    activePairing.DeviceName,
                    HashToken(authToken),
                    DateTime.UtcNow,
                    DateTime.UtcNow
                );

                _trustedDevices[deviceId] = pairedRecord;
                SaveTrustedDevices();
                _activePairings.Remove(deviceId);
                pairingExpired = true;
                paired = true;
            }
        }

        if (pairingExpired) PairingCodeExpired?.Invoke(deviceId);
        if (!paired) return false;

        DevicePaired?.Invoke(pairedRecord!);
        AppLogger.Instance.Info("Security", $"Device '{pairedRecord!.DeviceName}' successfully paired and trusted.");
        return true;
    }

    public bool AuthenticateDevice(string deviceId, string authToken, out TrustedDeviceRecord? record)
    {
        lock (_lock)
        {
            record = null;
            if (string.IsNullOrWhiteSpace(deviceId) || string.IsNullOrWhiteSpace(authToken))
            {
                return false;
            }

            if (!_trustedDevices.TryGetValue(deviceId, out var existing))
            {
                return false;
            }

            var hash = HashToken(authToken);
            if (!CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(hash),
                Convert.FromHexString(existing.TokenHash)))
            {
                return false;
            }

            // Update last seen
            record = existing with { LastSeen = DateTime.UtcNow };
            _trustedDevices[deviceId] = record;
            SaveTrustedDevices();

            return true;
        }
    }

    public void RevokeDevice(string deviceId)
    {
        lock (_lock)
        {
            if (_trustedDevices.Remove(deviceId))
            {
                SaveTrustedDevices();
                AppLogger.Instance.Info("Security", $"Device '{deviceId}' was revoked.");
                DeviceRevoked?.Invoke(deviceId);
            }
        }
    }

    public IReadOnlyList<TrustedDeviceRecord> GetTrustedDevices()
    {
        lock (_lock)
        {
            return _trustedDevices.Values.ToList();
        }
    }

    public IReadOnlyList<PairingRequestInfo> GetActivePairings()
    {
        lock (_lock)
        {
            var expired = _activePairings
                .Where(pair => pair.Value.IsExpired)
                .Select(pair => pair.Key)
                .ToList();
            foreach (var deviceId in expired) _activePairings.Remove(deviceId);
            return _activePairings.Values.OrderBy(pair => pair.ExpiresAt).ToList();
        }
    }

    private async Task ExpirePairingAsync(string deviceId, PairingRequestInfo request)
    {
        try
        {
            await Task.Delay(TimeSpan.FromSeconds(120));
            var expired = false;
            lock (_lock)
            {
                if (_activePairings.TryGetValue(deviceId, out var current) && ReferenceEquals(current, request) && current.IsExpired)
                {
                    _activePairings.Remove(deviceId);
                    expired = true;
                }
            }
            if (expired) PairingCodeExpired?.Invoke(deviceId);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Security", "Pairing expiry task failed.", ex);
        }
    }

    private static string HashToken(string token)
    {
        using var sha = SHA256.Create();
        var bytes = System.Text.Encoding.UTF8.GetBytes(token);
        var hash = sha.ComputeHash(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    private void SaveTrustedDevices()
    {
        try
        {
            var json = JsonSerializer.Serialize(_trustedDevices.Values, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_storageFilePath, json);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Security", "Failed to save trusted devices file.", ex);
        }
    }

    private void LoadTrustedDevices()
    {
        try
        {
            if (File.Exists(_storageFilePath))
            {
                var json = File.ReadAllText(_storageFilePath);
                var list = JsonSerializer.Deserialize<List<TrustedDeviceRecord>>(json);
                if (list != null)
                {
                    foreach (var d in list)
                    {
                        _trustedDevices[d.DeviceId] = d;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Security", "Failed to load trusted devices file.", ex);
        }
    }
}
