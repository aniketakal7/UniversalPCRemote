using System.Drawing;
using System.Windows.Forms;
using Microsoft.Win32;
using UniversalPCRemote.Companion.Applications;
using UniversalPCRemote.Companion.Clipboard;
using UniversalPCRemote.Companion.Diagnostics;
using UniversalPCRemote.Companion.Discovery;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Macros;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.Server;
using UniversalPCRemote.Companion.SystemControl;

namespace UniversalPCRemote.Companion.UI;

public class MainForm : Form
{
    private readonly CompanionWebSocketServer _server;
    private readonly DiscoveryBeacon _beacon;
    private readonly CommandRegistry _registry;
    private readonly SecurityManager _securityManager;

    // Controls
    private Label _lblStatus = null!;
    private Label _lblIpPort = null!;
    private Label _lblConnectedClients = null!;
    private Button _btnToggleServer = null!;
    private Panel _pnlPairingAlert = null!;
    private Label _lblPairingPin = null!;
    private Label _lblPairingDevice = null!;
    private ListBox _lstDevices = null!;
    private ListBox _lstLogs = null!;
    private ListView _lvDiagnostics = null!;
    private NotifyIcon _trayIcon = null!;
    private CheckBox _chkStartWithWindows = null!;
    private bool _suppressStartupSettingUpdate;

    private const string StartupRegistryPath = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
    private const string StartupValueName = "UniversalPCRemote";

    public MainForm()
    {
        Text = "Universal PC Remote™ by Aniket Akal — Companion Server";
        Width = 840;
        Height = 620;
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
        BackColor = Color.FromArgb(245, 247, 250);

        _securityManager = SecurityManager.Instance;
        _registry = new CommandRegistry(_securityManager);

        _server = new CompanionWebSocketServer(51234, _registry);
        _beacon = new DiscoveryBeacon(51234, 51235);

        // Register all command handlers
        RegisterHandlers();

        InitializeComponents();
        WireEvents();
    }

    private void RegisterHandlers()
    {
        var authHandler = new AuthCommandHandler(_securityManager);
        var inputHandler = new InputCommandHandler(NativeInputSimulator.Instance);
        var mediaHandler = new MediaCommandHandler(MediaController.Instance);
        var systemHandler = new SystemCommandHandler(SystemController.Instance);
        var clipboardHandler = new ClipboardCommandHandler(ClipboardController.Instance);
        var remoteHandler = new RemoteCommandHandler(RemoteCatalog.Instance);
        var macroHandler = new MacroCommandHandler(MacroEngine.Instance);
        var diagnosticsHandler = new DiagnosticsCommandHandler(() => _server.IsRunning, _server.Port);

        // Auth
        _registry.Register(CommandTypes.AuthPairRequest, authHandler);
        _registry.Register(CommandTypes.AuthPairVerify, authHandler);
        _registry.Register(CommandTypes.AuthAuthenticate, authHandler);
        _registry.Register(CommandTypes.SessionPing, authHandler);

        // Mouse & Keyboard
        _registry.Register(CommandTypes.MouseMove, inputHandler);
        _registry.Register(CommandTypes.MouseClick, inputHandler);
        _registry.Register(CommandTypes.MouseDown, inputHandler);
        _registry.Register(CommandTypes.MouseUp, inputHandler);
        _registry.Register(CommandTypes.MouseScroll, inputHandler);
        _registry.Register(CommandTypes.KeyboardText, inputHandler);
        _registry.Register(CommandTypes.KeyboardKey, inputHandler);
        _registry.Register(CommandTypes.KeyboardCombination, inputHandler);

        // Media
        _registry.Register(CommandTypes.MediaPlayPause, mediaHandler);
        _registry.Register(CommandTypes.MediaNext, mediaHandler);
        _registry.Register(CommandTypes.MediaPrevious, mediaHandler);
        _registry.Register(CommandTypes.MediaStop, mediaHandler);
        _registry.Register(CommandTypes.MediaSeekBackward, mediaHandler);
        _registry.Register(CommandTypes.MediaSeekForward, mediaHandler);
        _registry.Register(CommandTypes.MediaVolumeUp, mediaHandler);
        _registry.Register(CommandTypes.MediaVolumeDown, mediaHandler);
        _registry.Register(CommandTypes.MediaVolumeMute, mediaHandler);
        _registry.Register(CommandTypes.MediaGetStatus, mediaHandler);

        // System
        _registry.Register(CommandTypes.SystemLock, systemHandler);
        _registry.Register(CommandTypes.SystemSleep, systemHandler);
        _registry.Register(CommandTypes.SystemRestart, systemHandler);
        _registry.Register(CommandTypes.SystemShutdown, systemHandler);
        _registry.Register(CommandTypes.SystemCancelShutdown, systemHandler);
        _registry.Register(CommandTypes.SystemGetInfo, systemHandler);

        // Clipboard
        _registry.Register(CommandTypes.ClipboardGet, clipboardHandler);
        _registry.Register(CommandTypes.ClipboardSet, clipboardHandler);

        // Remotes
        _registry.Register(CommandTypes.RemoteList, remoteHandler);
        _registry.Register(CommandTypes.RemoteExecute, remoteHandler);

        // Macros
        _registry.Register(CommandTypes.MacroList, macroHandler);
        _registry.Register(CommandTypes.MacroExecute, macroHandler);

        // Diagnostics
        _registry.Register(CommandTypes.DiagnosticsStatus, diagnosticsHandler);
    }

    private void InitializeComponents()
    {
        // Header
        var header = new Panel
        {
            Dock = DockStyle.Top,
            Height = 70,
            BackColor = Color.FromArgb(24, 32, 44),
            Padding = new Padding(20, 10, 20, 10)
        };

        var title = new Label
        {
            Text = "Universal PC Remote™",
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 14f, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(20, 12)
        };

        var subtitle = new Label
        {
            Text = $"by Aniket Akal • PC: {Environment.MachineName} • Windows Companion Service",
            ForeColor = Color.FromArgb(170, 185, 205),
            Font = new Font("Segoe UI", 9f),
            AutoSize = true,
            Location = new Point(22, 40)
        };

        _btnToggleServer = new Button
        {
            Text = "Stop Server",
            Size = new Size(120, 36),
            Location = new Point(Width - 160, 16),
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
            BackColor = Color.FromArgb(220, 53, 69),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        _btnToggleServer.FlatAppearance.BorderSize = 0;
        _btnToggleServer.Click += async (_, _) => await ToggleServerAsync();

        header.Controls.AddRange(new Control[] { title, subtitle, _btnToggleServer });

        // Pairing PIN Banner (Hidden by default, shown when pairing is active)
        _pnlPairingAlert = new Panel
        {
            Dock = DockStyle.Top,
            Height = 110,
            BackColor = Color.FromArgb(254, 243, 199),
            Visible = false,
            Padding = new Padding(15)
        };

        var lblPairAlertTitle = new Label
        {
            Text = "PAIRING CODE ACTIVE — Enter this code in your phone app:",
            ForeColor = Color.FromArgb(146, 64, 14),
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            Location = new Point(20, 10),
            AutoSize = true
        };

        _lblPairingPin = new Label
        {
            Text = "000000",
            ForeColor = Color.FromArgb(180, 83, 9),
            Font = new Font("Consolas", 13f, FontStyle.Bold),
            Location = new Point(20, 32),
            Size = new Size(610, 64)
        };

        _lblPairingDevice = new Label
        {
            Visible = false
        };

        var btnCopyPin = new Button
        {
            Text = "📋 Copy PIN",
            Size = new Size(110, 34),
            Location = new Point(650, 8),
            BackColor = Color.FromArgb(217, 119, 6),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9f, FontStyle.Bold)
        };
        btnCopyPin.FlatAppearance.BorderSize = 0;
        btnCopyPin.Click += (_, _) =>
        {
            var firstPin = _securityManager.GetActivePairings().FirstOrDefault()?.Pin;
            if (!string.IsNullOrEmpty(firstPin))
            {
                System.Windows.Forms.Clipboard.SetText(firstPin);
                MessageBox.Show($"Pairing PIN {firstPin} copied to clipboard!", "Universal PC Remote™ by Aniket Akal", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        };

        _pnlPairingAlert.Controls.AddRange(new Control[] { lblPairAlertTitle, _lblPairingPin, btnCopyPin, _lblPairingDevice });

        // Tab Control
        var tabs = new TabControl
        {
            Dock = DockStyle.Fill,
            Padding = new Point(14, 8)
        };

        // Tab 1: Dashboard
        var tabDashboard = new TabPage("Dashboard");
        BuildDashboardTab(tabDashboard);

        // Tab 2: Paired Devices
        var tabDevices = new TabPage("Paired Devices");
        BuildDevicesTab(tabDevices);

        // Tab 3: Diagnostics
        var tabDiagnostics = new TabPage("Diagnostics");
        BuildDiagnosticsTab(tabDiagnostics);

        // Tab 4: Logs
        var tabLogs = new TabPage("Live Logs");
        BuildLogsTab(tabLogs);

        tabs.TabPages.AddRange(new[] { tabDashboard, tabDevices, tabDiagnostics, tabLogs });

        Controls.Add(tabs);
        Controls.Add(_pnlPairingAlert);
        Controls.Add(header);

        // App and Tray Icon
        Icon appIcon;
        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "assets", "app_icon.ico");
            if (File.Exists(iconPath))
            {
                appIcon = new Icon(iconPath);
            }
            else
            {
                appIcon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
            }
        }
        catch
        {
            appIcon = SystemIcons.Application;
        }
        Icon = appIcon;

        // Tray Icon
        _trayIcon = new NotifyIcon
        {
            Text = "Universal PC Remote™ by Aniket Akal",
            Icon = appIcon,
            Visible = true
        };
        _trayIcon.DoubleClick += (_, _) =>
        {
            Show();
            WindowState = FormWindowState.Normal;
            BringToFront();
        };

        var trayMenu = new ContextMenuStrip();
        var itemHeader = new ToolStripMenuItem("Universal PC Remote™ by Aniket Akal") { Enabled = false };
        trayMenu.Items.Add(itemHeader);
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("Open Companion Window", null, (_, _) =>
        {
            Show();
            WindowState = FormWindowState.Normal;
            BringToFront();
        });
        trayMenu.Items.Add("Copy Pairing PIN", null, (_, _) =>
        {
            if (_pnlPairingAlert.Visible && !string.IsNullOrEmpty(_lblPairingPin.Text))
            {
                System.Windows.Forms.Clipboard.SetText(_lblPairingPin.Text);
                _trayIcon.ShowBalloonTip(1500, "PIN Copied", $"Pairing PIN {_lblPairingPin.Text} copied to clipboard.", ToolTipIcon.Info);
            }
            else
            {
                MessageBox.Show("No active pairing session right now.", "Universal PC Remote™ by Aniket Akal", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        });
        trayMenu.Items.Add("Configure Windows Firewall", null, (_, _) => ConfigureFirewall());
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("Exit Companion", null, (_, _) =>
        {
            _trayIcon.Visible = false;
            Application.Exit();
        });
        _trayIcon.ContextMenuStrip = trayMenu;
    }

    private void BuildDashboardTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(25) };

        _lblStatus = new Label
        {
            Text = "Server Status: Running",
            Font = new Font("Segoe UI", 12f, FontStyle.Bold),
            ForeColor = Color.FromArgb(40, 167, 69),
            Location = new Point(25, 25),
            AutoSize = true
        };

        var ips = DiscoveryBeacon.GetLocalIpAddresses();
        var ipList = ips.Count > 0 ? string.Join(", ", ips) : "127.0.0.1";
        var hotspot = DiscoveryBeacon.GetHotspotInfo();
        var hotspotStatus = hotspot.IsConnected
            ? $"\n📱 Connected to Phone Hotspot (PC: {hotspot.PcIp} • Phone Gateway: {hotspot.PhoneGatewayIp})"
            : "";
        _lblIpPort = new Label
        {
            Text = $"IP Address(es): {ipList}\nPort: 51234 (WebSocket), 51235 (Discovery){hotspotStatus}",
            Font = new Font("Segoe UI", 10f),
            ForeColor = Color.FromArgb(50, 50, 50),
            Location = new Point(25, 60),
            AutoSize = true
        };

        _lblConnectedClients = new Label
        {
            Text = "Active Connected Devices: 0",
            Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
            ForeColor = Color.FromArgb(30, 41, 59),
            Location = new Point(25, 120),
            AutoSize = true
        };

        var quickTestBox = new GroupBox
        {
            Text = "Subsystem Quick Verification",
            Location = new Point(25, 160),
            Size = new Size(740, 140),
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold)
        };

        var btnTestCursor = new Button
        {
            Text = "Test Mouse Position",
            Location = new Point(20, 35),
            Size = new Size(160, 35),
            Font = new Font("Segoe UI", 9f)
        };
        btnTestCursor.Click += (_, _) =>
        {
            var (x, y) = NativeInputSimulator.Instance.GetCursorPosition();
            MessageBox.Show($"Current Cursor Position: X={x}, Y={y}", "Mouse Diagnostics", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };

        var btnTestMedia = new Button
        {
            Text = "Test Play/Pause Key",
            Location = new Point(190, 35),
            Size = new Size(160, 35),
            Font = new Font("Segoe UI", 9f)
        };
        btnTestMedia.Click += (_, _) => MediaController.Instance.PlayPause();

        var btnTestVolUp = new Button
        {
            Text = "Test Volume Up",
            Location = new Point(360, 35),
            Size = new Size(140, 35),
            Font = new Font("Segoe UI", 9f)
        };
        btnTestVolUp.Click += (_, _) => MediaController.Instance.VolumeUp(2);

        var btnTestVolDown = new Button
        {
            Text = "Test Volume Down",
            Location = new Point(510, 35),
            Size = new Size(140, 35),
            Font = new Font("Segoe UI", 9f)
        };
        btnTestVolDown.Click += (_, _) => MediaController.Instance.VolumeDown(2);

        var lblNote = new Label
        {
            Text = "Firewall Note: Ensure TCP 51234 & UDP 51235 are permitted in Windows Defender Firewall.",
            ForeColor = Color.FromArgb(100, 116, 139),
            Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
            Location = new Point(20, 90),
            AutoSize = true
        };

        quickTestBox.Controls.AddRange(new Control[] { btnTestCursor, btnTestMedia, btnTestVolUp, btnTestVolDown, lblNote });

        _chkStartWithWindows = new CheckBox
        {
            Text = "Start Universal PC Remote™ when I sign in",
            Checked = IsStartupEnabled(),
            AutoSize = true,
            Location = new Point(25, 320),
            Font = new Font("Segoe UI", 9.5f)
        };
        _chkStartWithWindows.CheckedChanged += (_, _) =>
        {
            if (!_suppressStartupSettingUpdate) UpdateStartupRegistration();
        };

        var btnFirewall = new Button
        {
            Text = "🛡️ Allow in Windows Firewall",
            Size = new Size(240, 34),
            Location = new Point(25, 360),
            BackColor = Color.FromArgb(241, 245, 249),
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9f, FontStyle.Regular)
        };
        btnFirewall.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
        btnFirewall.Click += (_, _) => ConfigureFirewall();

        _btnToggleServer = new Button
        {
            Text = "Restart Server",
            Size = new Size(130, 32),
            Location = new Point(630, 22),
            BackColor = Color.FromArgb(14, 165, 233),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9f, FontStyle.Bold)
        };
        _btnToggleServer.FlatAppearance.BorderSize = 0;
        _btnToggleServer.Click += async (_, _) => await ToggleServerAsync();

        pnl.Controls.AddRange(new Control[] { _lblStatus, _btnToggleServer, _lblIpPort, _lblConnectedClients, quickTestBox, _chkStartWithWindows, btnFirewall });
        page.Controls.Add(pnl);
    }

    private void BuildDevicesTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

        var lblTitle = new Label
        {
            Text = "Paired Trusted Devices",
            Font = new Font("Segoe UI", 11f, FontStyle.Bold),
            Location = new Point(20, 15),
            AutoSize = true
        };

        _lstDevices = new ListBox
        {
            Location = new Point(20, 50),
            Size = new Size(600, 240),
            Font = new Font("Consolas", 9.5f)
        };

        var btnRevoke = new Button
        {
            Text = "Revoke Selected",
            Location = new Point(630, 50),
            Size = new Size(140, 36),
            BackColor = Color.FromArgb(239, 68, 68),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        btnRevoke.FlatAppearance.BorderSize = 0;
        btnRevoke.Click += (_, _) => RevokeSelectedDevice();

        var btnRefresh = new Button
        {
            Text = "Refresh List",
            Location = new Point(630, 95),
            Size = new Size(140, 36)
        };
        btnRefresh.Click += (_, _) => RefreshDevicesList();

        pnl.Controls.AddRange(new Control[] { lblTitle, _lstDevices, btnRevoke, btnRefresh });
        page.Controls.Add(pnl);

        RefreshDevicesList();
    }

    private void BuildDiagnosticsTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

        var btnRun = new Button
        {
            Text = "Run Full Diagnostics",
            Location = new Point(20, 15),
            Size = new Size(180, 36),
            BackColor = Color.FromArgb(37, 99, 235),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        btnRun.FlatAppearance.BorderSize = 0;
        btnRun.Click += (_, _) => RunDiagnostics();

        _lvDiagnostics = new ListView
        {
            Location = new Point(20, 60),
            Size = new Size(760, 320),
            View = System.Windows.Forms.View.Details,
            FullRowSelect = true,
            GridLines = true
        };
        _lvDiagnostics.Columns.Add("Subsystem", 200);
        _lvDiagnostics.Columns.Add("Status", 90);
        _lvDiagnostics.Columns.Add("Message", 460);

        pnl.Controls.AddRange(new Control[] { btnRun, _lvDiagnostics });
        page.Controls.Add(pnl);
    }

    private void BuildLogsTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(15) };

        var btnClear = new Button
        {
            Text = "Clear Logs",
            Location = new Point(15, 10),
            Size = new Size(110, 30)
        };
        btnClear.Click += (_, _) => _lstLogs.Items.Clear();

        _lstLogs = new ListBox
        {
            Location = new Point(15, 50),
            Size = new Size(770, 340),
            Font = new Font("Consolas", 8.5f)
        };

        pnl.Controls.AddRange(new Control[] { btnClear, _lstLogs });
        page.Controls.Add(pnl);
    }

    private void WireEvents()
    {
        _server.ClientConnected += session =>
        {
            Invoke(() =>
            {
                _lblConnectedClients.Text = $"Active Connected Devices: {_server.ActiveClientCount}";
            });
        };

        _server.ClientDisconnected += session =>
        {
            Invoke(() =>
            {
                _lblConnectedClients.Text = $"Active Connected Devices: {_server.ActiveClientCount}";
            });
        };

        _securityManager.PairingCodeGenerated += (_, _, _) =>
        {
            Invoke(() =>
            {
                RefreshPairingAlert();
            });
        };

        _securityManager.PairingCodeExpired += _ =>
        {
            Invoke(() =>
            {
                RefreshPairingAlert();
            });
        };

        _securityManager.DevicePaired += _ =>
        {
            Invoke(RefreshDevicesList);
        };

        AppLogger.Instance.LogEmitted += entry =>
        {
            if (IsDisposed || !IsHandleCreated) return;
            try
            {
                BeginInvoke(() =>
                {
                    if (_lstLogs.Items.Count > 500) _lstLogs.Items.RemoveAt(0);
                    _lstLogs.Items.Add($"[{entry.Timestamp:HH:mm:ss}] [{entry.Level.ToString()[..1]}] [{entry.Component}] {entry.Message}");
                    _lstLogs.TopIndex = _lstLogs.Items.Count - 1;
                });
            }
            catch
            {
                // Form closing
            }
        };
    }

    private void RefreshPairingAlert()
    {
        var pairings = _securityManager.GetActivePairings();
        _pnlPairingAlert.Visible = pairings.Count > 0;
        _lblPairingPin.Text = string.Join(Environment.NewLine,
            pairings.Select(pairing => $"{pairing.Pin}  -  {pairing.DeviceName}"));
    }

    private async void StartServices()
    {
        try
        {
            await _server.StartAsync();
            _beacon.Start();
            _lblStatus.Text = "Server Status: Running (Port 51234)";
            _lblStatus.ForeColor = Color.FromArgb(40, 167, 69);
            _btnToggleServer.Text = "Stop Server";
            _btnToggleServer.BackColor = Color.FromArgb(220, 53, 69);

            var ips = DiscoveryBeacon.GetLocalIpAddresses();
            var ipList = ips.Count > 0 ? string.Join(", ", ips) : "127.0.0.1";
            var hotspot = DiscoveryBeacon.GetHotspotInfo();
            var hotspotStatus = hotspot.IsConnected
                ? $"\n📱 Connected to Phone Hotspot (PC: {hotspot.PcIp} • Phone Gateway: {hotspot.PhoneGatewayIp})"
                : "";
            _lblIpPort.Text = $"IP Address(es): {ipList}\nPort: 51234 (WebSocket), 51235 (Discovery){hotspotStatus}";
        }
        catch (Exception ex)
        {
            _lblStatus.Text = $"Server Error: {ex.Message}";
            _lblStatus.ForeColor = Color.Red;
            _btnToggleServer.Text = "Start Server";
            _btnToggleServer.BackColor = Color.FromArgb(40, 167, 69);
        }
    }

    private async Task ToggleServerAsync()
    {
        if (_server.IsRunning)
        {
            await _server.StopAsync();
            _beacon.Stop();
            _lblStatus.Text = "Server Status: Stopped";
            _lblStatus.ForeColor = Color.FromArgb(108, 117, 125);
            _btnToggleServer.Text = "Start Server";
            _btnToggleServer.BackColor = Color.FromArgb(40, 167, 69);
        }
        else
        {
            StartServices();
        }
    }

    private void RefreshDevicesList()
    {
        _lstDevices.Items.Clear();
        var devices = _securityManager.GetTrustedDevices();
        if (devices.Count == 0)
        {
            _lstDevices.Items.Add("(No trusted devices paired yet)");
            return;
        }

        foreach (var d in devices)
        {
            _lstDevices.Items.Add($"{d.DeviceName} | ID: {d.DeviceId} | Paired: {d.PairedAt:yyyy-MM-dd HH:mm}");
        }
    }

    private void RevokeSelectedDevice()
    {
        if (_lstDevices.SelectedIndex < 0) return;
        var text = _lstDevices.SelectedItem?.ToString();
        if (string.IsNullOrEmpty(text) || text.StartsWith("(")) return;

        var parts = text.Split('|');
        if (parts.Length > 1)
        {
            var idPart = parts[1].Replace("ID:", "").Trim();
            _securityManager.RevokeDevice(idPart);
            RefreshDevicesList();
            MessageBox.Show($"Device '{idPart}' has been revoked.", "Revoke Device", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void RunDiagnostics()
    {
        _lvDiagnostics.Items.Clear();
        var report = DiagnosticsManager.Instance.RunDiagnostics(_server.IsRunning, _server.Port);

        foreach (var item in report.Items)
        {
            var lvi = new ListViewItem(item.Subsystem);
            lvi.SubItems.Add(item.Status);
            lvi.SubItems.Add(item.Message);

            if (item.Status == "PASS")
            {
                lvi.ForeColor = Color.FromArgb(22, 101, 52);
            }
            else
            {
                lvi.ForeColor = Color.FromArgb(185, 28, 28);
            }

            _lvDiagnostics.Items.Add(lvi);
        }
    }

    private static bool IsStartupEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(StartupRegistryPath, writable: false);
        return key?.GetValue(StartupValueName) is string;
    }

    private void UpdateStartupRegistration()
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(StartupRegistryPath, writable: true)
                ?? throw new InvalidOperationException("Windows startup settings could not be opened.");

            if (_chkStartWithWindows.Checked)
            {
                var executablePath = Environment.ProcessPath;
                if (string.IsNullOrWhiteSpace(executablePath) || !executablePath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException("Startup can be enabled only from the published Companion executable.");
                }

                key.SetValue(StartupValueName, $"\"{executablePath}\" --minimized", RegistryValueKind.String);
                AppLogger.Instance.Info("Startup", "Companion configured to start automatically at sign-in.");
            }
            else
            {
                key.DeleteValue(StartupValueName, throwOnMissingValue: false);
                AppLogger.Instance.Info("Startup", "Automatic companion startup disabled.");
            }
        }
        catch (Exception ex)
        {
            _suppressStartupSettingUpdate = true;
            _chkStartWithWindows.Checked = !_chkStartWithWindows.Checked;
            _suppressStartupSettingUpdate = false;
            AppLogger.Instance.Error("Startup", "Failed to update automatic startup setting.", ex);
            MessageBox.Show(ex.Message, "Universal PC Remote™ by Aniket Akal", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void ConfigureFirewall()
    {
        try
        {
            var exePath = Environment.ProcessPath ?? Application.ExecutablePath;
            var script = $@"@echo off
netsh advfirewall firewall add rule name=""Universal PC Remote (TCP 51234)"" dir=in action=allow protocol=TCP localport=51234 profile=any
netsh advfirewall firewall add rule name=""Universal PC Remote (UDP 51235)"" dir=in action=allow protocol=UDP localport=51235 profile=any
if exist ""{exePath}"" (
    netsh advfirewall firewall add rule name=""Universal PC Remote Companion App"" dir=in action=allow program=""{exePath}"" enable=yes profile=any
)
";
            var tempBat = Path.Combine(Path.GetTempPath(), "setup_pcremote_firewall.bat");
            File.WriteAllText(tempBat, script);

            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c \"\"{tempBat}\"\"",
                Verb = "runas",
                UseShellExecute = true,
                WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden
            };
            var proc = System.Diagnostics.Process.Start(psi);
            proc?.WaitForExit(6000);

            try { File.Delete(tempBat); } catch { }

            MessageBox.Show(
                "Windows Defender Firewall rules have been successfully registered!\n\n• TCP Port 51234 (WebSocket Commands)\n• UDP Port 51235 (Discovery Beacon)\n• Application Exemption",
                "Firewall Configured",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to configure firewall: {ex.Message}\n\nMake sure to approve the Administrator prompt or run scripts\\setup_firewall.bat.",
                "Firewall Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            );
        }
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        StartServices();

        if (Environment.GetCommandLineArgs().Any(arg => string.Equals(arg, "--minimized", StringComparison.OrdinalIgnoreCase)))
        {
            BeginInvoke(() =>
            {
                Hide();
                ShowInTaskbar = false;
            });
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
            _trayIcon.ShowBalloonTip(2000, "Universal PC Remote™", "Universal PC Remote™ by Aniket Akal companion server running in background.", ToolTipIcon.Info);
        }
        else
        {
            _beacon.Dispose();
            _server.StopAsync().GetAwaiter().GetResult();
            base.OnFormClosing(e);
        }
    }
}
