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
    private PairingRequestInfo? _activePairing;

    public event Action<string, string>? PairingCodeGenerated; // pin, deviceName
    public event Action? PairingCodeExpired;
    public event Action<TrustedDeviceRecord>? DevicePaired;
    public event Action<string>? DeviceRevoked;

    public string? CurrentPairingPin => _activePairing is { IsExpired: false } ? _activePairing.Pin : null;

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
        lock (_lock)
        {
            // Generate a secure 6-digit random PIN
            var randomBytes = new byte[4];
            RandomNumberGenerator.Fill(randomBytes);
            var pinNum = (BitConverter.ToUInt32(randomBytes, 0) % 900000) + 100000;
            var pin = pinNum.ToString("D6");

            _activePairing = new PairingRequestInfo(pin, deviceId, deviceName, TimeSpan.FromSeconds(120));

            AppLogger.Instance.Info("Security", $"Pairing PIN generated for device '{deviceName}' ({deviceId}). Expires in 120s.");
            PairingCodeGenerated?.Invoke(pin, deviceName);

            return pin;
        }
    }

    public bool VerifyPairing(string deviceId, string pin, out string? authToken, out string? errorMessage)
    {
        lock (_lock)
        {
            authToken = null;
            errorMessage = null;

            if (_activePairing == null || _activePairing.IsExpired)
            {
                _activePairing = null;
                PairingCodeExpired?.Invoke();
                errorMessage = "Pairing session has expired or was not initiated. Please request a new pairing code.";
                return false;
            }

            if (_activePairing.DeviceId != deviceId)
            {
                errorMessage = "Pairing request mismatch. Device ID does not match active request.";
                return false;
            }

            if (_activePairing.FailedAttempts >= 5)
            {
                _activePairing = null;
                PairingCodeExpired?.Invoke();
                errorMessage = "Too many failed attempts. Pairing cancelled for security.";
                return false;
            }

            if (!string.Equals(_activePairing.Pin, pin.Trim(), StringComparison.Ordinal))
            {
                _activePairing.FailedAttempts++;
                errorMessage = "Invalid pairing code. Please check the code displayed on your PC screen.";
                return false;
            }

            // PIN is correct! Generate a high-entropy auth token
            var tokenBytes = new byte[32];
            RandomNumberGenerator.Fill(tokenBytes);
            authToken = Convert.ToHexString(tokenBytes).ToLowerInvariant();

            var tokenHash = HashToken(authToken);
            var record = new TrustedDeviceRecord(
                deviceId,
                _activePairing.DeviceName,
                tokenHash,
                DateTime.UtcNow,
                DateTime.UtcNow
            );

            _trustedDevices[deviceId] = record;
            SaveTrustedDevices();

            _activePairing = null;
            PairingCodeExpired?.Invoke();
            DevicePaired?.Invoke(record);

            AppLogger.Instance.Info("Security", $"Device '{record.DeviceName}' successfully paired and trusted.");
            return true;
        }
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
