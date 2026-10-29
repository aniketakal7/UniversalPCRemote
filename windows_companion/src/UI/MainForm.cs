using System.Drawing;
using System.Net.NetworkInformation;
using System.Windows.Forms;
using Microsoft.Win32;
using UniversalPCRemote.Companion.Discovery;
using UniversalPCRemote.Companion.Diagnostics;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.Server;

namespace UniversalPCRemote.Companion.UI;

public class MainForm : Form
{
    private readonly CompanionWebSocketServer _server;
    private readonly DiscoveryBeacon _beacon;
    private readonly CommandRegistry _registry;
    private readonly SecurityManager _securityManager;

    // Header controls — kept as separate named fields to avoid the previous bug
    // where _btnToggleServer was reassigned inside BuildDashboardTab.
    private Button _btnHeaderToggle = null!;   // lives in the dark header bar
    private Label  _lblHeaderStatus = null!;   // "● Running" indicator in header

    // Dashboard tab controls
    private Label    _lblStatus          = null!;
    private Label    _lblIpPort          = null!;
    private Label    _lblConnectedClients = null!;
    private CheckBox _chkStartWithWindows = null!;

    // Pairing banner controls
    private Panel _pnlPairingAlert = null!;
    private Label _lblPairingPin   = null!;
    private Label _lblPairingTimer = null!;

    // Devices tab
    private ListView _lvDevices = null!;

    // Diagnostics tab
    private ListView _lvDiagnostics = null!;

    // Logs tab
    private ListBox _lstLogs = null!;

    // Settings tab
    private NumericUpDown _nudPort            = null!;
    private NumericUpDown _nudMouseSensitivity = null!;
    private NumericUpDown _nudScrollStep       = null!;
    private CheckBox      _chkAllowShutdown    = null!;
    private CheckBox      _chkAllowSleep       = null!;
    private CheckBox      _chkAllowRestart     = null!;

    // System tray
    private NotifyIcon _trayIcon = null!;

    // Pairing countdown
    private System.Windows.Forms.Timer _pairingCountdownTimer = null!;
    private DateTime _pairingExpiresAt = DateTime.MinValue;

    // Startup registry
    private bool _suppressStartupSettingUpdate;
    private const string StartupRegistryPath = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
    private const string StartupValueName    = "UniversalPCRemote";

    public MainForm()
    {
        Text            = "Universal PC Remote™ by Aniket Akal — Companion Server";
        Width           = 900;
        Height          = 650;
        MinimumSize     = new Size(720, 520);
        StartPosition   = FormStartPosition.CenterScreen;
        Font            = new Font("Segoe UI", 9.5f, FontStyle.Regular);
        BackColor       = Color.FromArgb(245, 247, 250);

        _securityManager = SecurityManager.Instance;
        _registry        = new CommandRegistry(_securityManager);
        _server          = new CompanionWebSocketServer(51234, _registry);
        _beacon          = new DiscoveryBeacon(51234, 51235);

        // Single registration point — no duplication with Program.cs
        HandlerRegistrar.RegisterAll(_registry, _securityManager, () => _server.IsRunning, _server.Port);

        InitializeComponents();
        WireEvents();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  UI CONSTRUCTION
    // ─────────────────────────────────────────────────────────────────────────

    private void InitializeComponents()
    {
        // ── Header bar ─────────────────────────────────────────────────────
        var header = new Panel
        {
            Dock      = DockStyle.Top,
            Height    = 70,
            BackColor = Color.FromArgb(24, 32, 44),
            Padding   = new Padding(20, 10, 20, 10)
        };

        var title = new Label
        {
            Text      = "Universal PC Remote™",
            ForeColor = Color.White,
            Font      = new Font("Segoe UI", 14f, FontStyle.Bold),
            AutoSize  = true,
            Location  = new Point(20, 12)
        };

        var subtitle = new Label
        {
            Text      = $"by Aniket Akal  •  PC: {Environment.MachineName}  •  Windows Companion Service",
            ForeColor = Color.FromArgb(170, 185, 205),
            Font      = new Font("Segoe UI", 9f),
            AutoSize  = true,
            Location  = new Point(22, 40)
        };

        _lblHeaderStatus = new Label
        {
            Text      = "● Running",
            ForeColor = Color.FromArgb(74, 222, 128),
            Font      = new Font("Segoe UI", 9f, FontStyle.Bold),
            AutoSize  = true,
            Location  = new Point(header.Width - 260, 26),
            Anchor    = AnchorStyles.Top | AnchorStyles.Right
        };

        _btnHeaderToggle = new Button
        {
            Text      = "Stop Server",
            Size      = new Size(120, 36),
            Location  = new Point(header.Width - 148, 16),
            Anchor    = AnchorStyles.Top | AnchorStyles.Right,
            BackColor = Color.FromArgb(220, 53, 69),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        _btnHeaderToggle.FlatAppearance.BorderSize = 0;
        _btnHeaderToggle.Click += async (_, _) => await ToggleServerAsync();

        header.Controls.AddRange(new Control[] { title, subtitle, _lblHeaderStatus, _btnHeaderToggle });

        // ── Pairing PIN banner ──────────────────────────────────────────────
        _pnlPairingAlert = new Panel
        {
            Dock      = DockStyle.Top,
            Height    = 80,
            BackColor = Color.FromArgb(254, 243, 199),
            Visible   = false,
            Padding   = new Padding(15)
        };

        var lblPairTitle = new Label
        {
            Text      = "⚠  PAIRING CODE ACTIVE — Enter this code in your phone app:",
            ForeColor = Color.FromArgb(146, 64, 14),
            Font      = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            Location  = new Point(20, 8),
            AutoSize  = true
        };

        _lblPairingPin = new Label
        {
            Text      = "000000",
            ForeColor = Color.FromArgb(180, 83, 9),
            Font      = new Font("Consolas", 22f, FontStyle.Bold),
            Location  = new Point(20, 28),
            AutoSize  = true
        };

        _lblPairingTimer = new Label
        {
            Text      = "Expires in: 2:00",
            ForeColor = Color.FromArgb(120, 53, 15),
            Font      = new Font("Segoe UI", 9f),
            Location  = new Point(170, 40),
            AutoSize  = true
        };

        var btnCopyPin = new Button
        {
            Text      = "📋 Copy PIN",
            Size      = new Size(110, 32),
            Location  = new Point(680, 22),
            Anchor    = AnchorStyles.Top | AnchorStyles.Right,
            BackColor = Color.FromArgb(217, 119, 6),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Font      = new Font("Segoe UI", 9f, FontStyle.Bold)
        };
        btnCopyPin.FlatAppearance.BorderSize = 0;
        btnCopyPin.Click += (_, _) =>
        {
            var firstPin = _securityManager.GetActivePairings().FirstOrDefault()?.Pin;
            if (!string.IsNullOrEmpty(firstPin))
            {
                System.Windows.Forms.Clipboard.SetText(firstPin);
                _trayIcon.ShowBalloonTip(1500, "PIN Copied", $"Pairing PIN {firstPin} copied to clipboard.", ToolTipIcon.Info);
            }
        };

        _pnlPairingAlert.Controls.AddRange(new Control[] { lblPairTitle, _lblPairingPin, _lblPairingTimer, btnCopyPin });

        // ── Tab control ─────────────────────────────────────────────────────
        var tabs = new TabControl
        {
            Dock    = DockStyle.Fill,
            Padding = new Point(14, 8)
        };

        var tabDashboard   = new TabPage("Dashboard");
        var tabDevices     = new TabPage("Paired Devices");
        var tabDiagnostics = new TabPage("Diagnostics");
        var tabLogs        = new TabPage("Live Logs");
        var tabSettings    = new TabPage("Settings");

        BuildDashboardTab(tabDashboard);
        BuildDevicesTab(tabDevices);
        BuildDiagnosticsTab(tabDiagnostics);
        BuildLogsTab(tabLogs);
        BuildSettingsTab(tabSettings);

        tabs.TabPages.AddRange(new[] { tabDashboard, tabDevices, tabDiagnostics, tabLogs, tabSettings });

        // Z-order: tabs at bottom, then pairing banner, then header on top
        Controls.Add(tabs);
        Controls.Add(_pnlPairingAlert);
        Controls.Add(header);

        // ── App icon ─────────────────────────────────────────────────────
        Icon appIcon;
        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "assets", "app_icon.ico");
            appIcon = File.Exists(iconPath)
                ? new Icon(iconPath)
                : System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;
        }
        catch
        {
            appIcon = SystemIcons.Application;
        }
        Icon = appIcon;

        // ── System tray ──────────────────────────────────────────────────
        _trayIcon = new NotifyIcon
        {
            Text    = "Universal PC Remote™ by Aniket Akal",
            Icon    = appIcon,
            Visible = true
        };
        _trayIcon.DoubleClick += (_, _) => BringToForeground();

        var trayMenu   = new ContextMenuStrip();
        var itemHeader = new ToolStripMenuItem("Universal PC Remote™ by Aniket Akal") { Enabled = false };
        trayMenu.Items.Add(itemHeader);
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("Open Companion Window",   null, (_, _) => BringToForeground());
        trayMenu.Items.Add("Copy Pairing PIN",        null, (_, _) => CopyPairingPinToClipboard());
        trayMenu.Items.Add("Configure Windows Firewall", null, (_, _) => ConfigureFirewall());
        trayMenu.Items.Add(new ToolStripSeparator());
        trayMenu.Items.Add("Exit Companion", null, (_, _) =>
        {
            _trayIcon.Visible = false;
            Application.Exit();
        });
        _trayIcon.ContextMenuStrip = trayMenu;

        // ── Pairing countdown timer ───────────────────────────────────────
        _pairingCountdownTimer = new System.Windows.Forms.Timer { Interval = 500 };
        _pairingCountdownTimer.Tick += (_, _) => TickPairingCountdown();
    }

    // ─── Dashboard ────────────────────────────────────────────────────────────
    private void BuildDashboardTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(25) };

        _lblStatus = new Label
        {
            Text      = "Server Status: Running (Port 51234)",
            Font      = new Font("Segoe UI", 12f, FontStyle.Bold),
            ForeColor = Color.FromArgb(40, 167, 69),
            Location  = new Point(25, 25),
            AutoSize  = true
        };

        var ips        = DiscoveryBeacon.GetLocalIpAddresses();
        var ipList     = ips.Count > 0 ? string.Join(", ", ips) : "127.0.0.1";
        var hotspot    = DiscoveryBeacon.GetHotspotInfo();
        var hotspotTxt = hotspot.IsConnected
            ? $"\n📱 Hotspot: PC {hotspot.PcIp} | Phone Gateway {hotspot.PhoneGatewayIp}"
            : "";

        _lblIpPort = new Label
        {
            Text     = $"IP Address(es): {ipList}\nPort: 51234 (WebSocket)  •  51235 (Discovery){hotspotTxt}",
            Font     = new Font("Segoe UI", 10f),
            ForeColor= Color.FromArgb(50, 50, 50),
            Location = new Point(25, 60),
            AutoSize = true
        };

        _lblConnectedClients = new Label
        {
            Text      = "Active Connected Devices: 0",
            Font      = new Font("Segoe UI", 10.5f, FontStyle.Bold),
            ForeColor = Color.FromArgb(30, 41, 59),
            Location  = new Point(25, 120),
            AutoSize  = true
        };

        // Quick test box
        var quickTestBox = new GroupBox
        {
            Text     = "Subsystem Quick Verification",
            Location = new Point(25, 155),
            Size     = new Size(800, 100),
            Font     = new Font("Segoe UI", 9.5f, FontStyle.Bold)
        };

        var btnTestCursor = new Button
        {
            Text     = "Test Mouse Position",
            Location = new Point(15, 30),
            Size     = new Size(160, 35),
            Font     = new Font("Segoe UI", 9f)
        };
        btnTestCursor.Click += (_, _) =>
        {
            var (x, y) = NativeInputSimulator.Instance.GetCursorPosition();
            MessageBox.Show($"Current Cursor Position: X={x}, Y={y}", "Mouse Diagnostics", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };

        var btnTestMedia = new Button
        {
            Text     = "Test Play/Pause",
            Location = new Point(185, 30),
            Size     = new Size(140, 35),
            Font     = new Font("Segoe UI", 9f)
        };
        btnTestMedia.Click += (_, _) => MediaController.Instance.PlayPause();

        var btnTestVolUp = new Button
        {
            Text     = "Volume Up",
            Location = new Point(335, 30),
            Size     = new Size(120, 35),
            Font     = new Font("Segoe UI", 9f)
        };
        btnTestVolUp.Click += (_, _) => MediaController.Instance.VolumeUp(2);

        var btnTestVolDown = new Button
        {
            Text     = "Volume Down",
            Location = new Point(465, 30),
            Size     = new Size(120, 35),
            Font     = new Font("Segoe UI", 9f)
        };
        btnTestVolDown.Click += (_, _) => MediaController.Instance.VolumeDown(2);

        var lblNote = new Label
        {
            Text      = "Firewall: Ensure TCP 51234 & UDP 51235 are allowed in Windows Defender Firewall.",
            ForeColor = Color.FromArgb(100, 116, 139),
            Font      = new Font("Segoe UI", 8.5f),
            Location  = new Point(15, 72),
            AutoSize  = true
        };

        quickTestBox.Controls.AddRange(new Control[] { btnTestCursor, btnTestMedia, btnTestVolUp, btnTestVolDown, lblNote });

        _chkStartWithWindows = new CheckBox
        {
            Text     = "Start Universal PC Remote™ when I sign in to Windows",
            Checked  = IsStartupEnabled(),
            AutoSize = true,
            Location = new Point(25, 272),
            Font     = new Font("Segoe UI", 9.5f)
        };
        _chkStartWithWindows.CheckedChanged += (_, _) =>
        {
            if (!_suppressStartupSettingUpdate) UpdateStartupRegistration();
        };

        var btnFirewall = new Button
        {
            Text      = "🛡️ Allow in Windows Firewall",
            Size      = new Size(240, 34),
            Location  = new Point(25, 308),
            BackColor = Color.FromArgb(241, 245, 249),
            FlatStyle = FlatStyle.Flat,
            Font      = new Font("Segoe UI", 9f)
        };
        btnFirewall.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
        btnFirewall.Click += (_, _) => ConfigureFirewall();

        var lblLogPath = new Label
        {
            Text      = $"Log file: %LOCALAPPDATA%\\UniversalPCRemote\\companion.log",
            ForeColor = Color.FromArgb(100, 116, 139),
            Font      = new Font("Segoe UI", 8.5f),
            Location  = new Point(25, 360),
            AutoSize  = true
        };

        pnl.Controls.AddRange(new Control[]
        {
            _lblStatus, _lblIpPort, _lblConnectedClients,
            quickTestBox, _chkStartWithWindows, btnFirewall, lblLogPath
        });
        page.Controls.Add(pnl);
    }

    // ─── Paired Devices ───────────────────────────────────────────────────────
    private void BuildDevicesTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

        var lblTitle = new Label
        {
            Text     = "Paired Trusted Devices",
            Font     = new Font("Segoe UI", 11f, FontStyle.Bold),
            Location = new Point(20, 12),
            AutoSize = true
        };

        _lvDevices = new ListView
        {
            Location      = new Point(20, 45),
            Anchor        = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom,
            Size          = new Size(700, 320),
            View          = System.Windows.Forms.View.Details,
            FullRowSelect = true,
            GridLines     = true,
            Font          = new Font("Segoe UI", 9f)
        };
        _lvDevices.Columns.Add("Device Name", 200);
        _lvDevices.Columns.Add("Device ID",   220);
        _lvDevices.Columns.Add("Paired At",   140);
        _lvDevices.Columns.Add("Last Seen",   140);

        var btnRevoke = new Button
        {
            Text      = "Revoke Selected",
            Location  = new Point(730, 45),
            Size      = new Size(140, 36),
            Anchor    = AnchorStyles.Top | AnchorStyles.Right,
            BackColor = Color.FromArgb(239, 68, 68),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        btnRevoke.FlatAppearance.BorderSize = 0;
        btnRevoke.Click += (_, _) => RevokeSelectedDevice();

        var btnRefresh = new Button
        {
            Text      = "Refresh",
            Location  = new Point(730, 90),
            Size      = new Size(140, 36),
            Anchor    = AnchorStyles.Top | AnchorStyles.Right,
            FlatStyle = FlatStyle.Flat
        };
        btnRefresh.FlatAppearance.BorderColor = Color.FromArgb(203, 213, 225);
        btnRefresh.Click += (_, _) => RefreshDevicesList();

        pnl.Controls.AddRange(new Control[] { lblTitle, _lvDevices, btnRevoke, btnRefresh });
        page.Controls.Add(pnl);

        RefreshDevicesList();
    }

    // ─── Diagnostics ─────────────────────────────────────────────────────────
    private void BuildDiagnosticsTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };

        var btnRun = new Button
        {
            Text      = "▶  Run Full Diagnostics",
            Location  = new Point(20, 12),
            Size      = new Size(200, 36),
            BackColor = Color.FromArgb(37, 99, 235),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        btnRun.FlatAppearance.BorderSize = 0;
        btnRun.Click += (_, _) => RunDiagnostics();

        _lvDiagnostics = new ListView
        {
            Location      = new Point(20, 60),
            Anchor        = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom,
            Size          = new Size(820, 360),
            View          = System.Windows.Forms.View.Details,
            FullRowSelect = true,
            GridLines     = true
        };
        _lvDiagnostics.Columns.Add("Subsystem", 200);
        _lvDiagnostics.Columns.Add("Status",     90);
        _lvDiagnostics.Columns.Add("Message",   520);

        pnl.Controls.AddRange(new Control[] { btnRun, _lvDiagnostics });
        page.Controls.Add(pnl);
    }

    // ─── Live Logs ────────────────────────────────────────────────────────────
    private void BuildLogsTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(15) };

        var btnClear = new Button
        {
            Text     = "Clear",
            Location = new Point(15, 10),
            Size     = new Size(90, 28)
        };
        btnClear.Click += (_, _) => _lstLogs.Items.Clear();

        var btnOpenLogFile = new Button
        {
            Text     = "Open Log File",
            Location = new Point(115, 10),
            Size     = new Size(120, 28)
        };
        btnOpenLogFile.Click += (_, _) =>
        {
            var logPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "UniversalPCRemote", "companion.log");
            if (File.Exists(logPath))
                System.Diagnostics.Process.Start("notepad.exe", logPath);
            else
                MessageBox.Show("No log file found yet.", "Live Logs", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };

        // Level filter combo
        var lblFilter = new Label
        {
            Text     = "Filter:",
            Location = new Point(250, 14),
            AutoSize = true,
            Font     = new Font("Segoe UI", 9f)
        };
        var cmbFilter = new ComboBox
        {
            Location      = new Point(290, 10),
            Size          = new Size(100, 26),
            DropDownStyle = ComboBoxStyle.DropDownList,
            Font          = new Font("Segoe UI", 9f)
        };
        cmbFilter.Items.AddRange(new object[] { "ALL", "INFO", "WARN", "ERROR" });
        cmbFilter.SelectedIndex = 0;

        _lstLogs = new ListBox
        {
            Location         = new Point(15, 48),
            Anchor           = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom,
            Size             = new Size(830, 420),
            Font             = new Font("Consolas", 8.5f),
            HorizontalScrollbar = true
        };

        // Wire filter: rebuild list from in-memory log on change
        cmbFilter.SelectedIndexChanged += (_, _) =>
        {
            var filterText = cmbFilter.SelectedItem?.ToString() ?? "ALL";
            _lstLogs.Items.Clear();
            foreach (var entry in AppLogger.Instance.GetRecentLogs())
            {
                if (filterText == "ALL" ||
                    entry.Level.ToString().ToUpperInvariant().StartsWith(filterText, StringComparison.Ordinal))
                {
                    _lstLogs.Items.Add(FormatLogEntry(entry));
                }
            }
        };

        pnl.Controls.AddRange(new Control[] { btnClear, btnOpenLogFile, lblFilter, cmbFilter, _lstLogs });
        page.Controls.Add(pnl);
    }

    // ─── Settings ─────────────────────────────────────────────────────────────
    private void BuildSettingsTab(TabPage page)
    {
        page.BackColor = Color.White;
        var pnl = new Panel { Dock = DockStyle.Fill, Padding = new Padding(25) };

        int y = 15;

        var lblNetwork = new Label
        {
            Text     = "Network",
            Font     = new Font("Segoe UI", 10f, FontStyle.Bold),
            Location = new Point(0, y),
            AutoSize = true,
            ForeColor= Color.FromArgb(30, 41, 59)
        };
        y += 28;

        var lblPort = new Label { Text = "WebSocket Port:", Location = new Point(0, y + 4), AutoSize = true, Font = new Font("Segoe UI", 9.5f) };
        _nudPort = new NumericUpDown
        {
            Location = new Point(160, y),
            Size     = new Size(90, 26),
            Minimum  = 1024,
            Maximum  = 65535,
            Value    = 51234,
            Font     = new Font("Segoe UI", 9.5f)
        };
        var lblPortNote = new Label
        {
            Text      = "(Takes effect after restarting the server)",
            Location  = new Point(260, y + 4),
            AutoSize  = true,
            Font      = new Font("Segoe UI", 8.5f),
            ForeColor = Color.FromArgb(107, 114, 128)
        };
        y += 40;

        var sep1 = new Label { Location = new Point(0, y), Size = new Size(820, 1), BackColor = Color.FromArgb(229, 231, 235) };
        y += 12;

        var lblInput = new Label
        {
            Text     = "Input",
            Font     = new Font("Segoe UI", 10f, FontStyle.Bold),
            Location = new Point(0, y),
            AutoSize = true,
            ForeColor= Color.FromArgb(30, 41, 59)
        };
        y += 28;

        var lblMouse = new Label { Text = "Mouse Sensitivity Multiplier:", Location = new Point(0, y + 4), AutoSize = true, Font = new Font("Segoe UI", 9.5f) };
        _nudMouseSensitivity = new NumericUpDown
        {
            Location      = new Point(220, y),
            Size          = new Size(80, 26),
            Minimum       = 1,
            Maximum       = 10,
            Value         = 2,
            DecimalPlaces = 0,
            Font          = new Font("Segoe UI", 9.5f)
        };
        y += 38;

        var lblScroll = new Label { Text = "Scroll Step (lines per tick):", Location = new Point(0, y + 4), AutoSize = true, Font = new Font("Segoe UI", 9.5f) };
        _nudScrollStep = new NumericUpDown
        {
            Location  = new Point(220, y),
            Size      = new Size(80, 26),
            Minimum   = 1,
            Maximum   = 20,
            Value     = 3,
            Font      = new Font("Segoe UI", 9.5f)
        };
        y += 40;

        var sep2 = new Label { Location = new Point(0, y), Size = new Size(820, 1), BackColor = Color.FromArgb(229, 231, 235) };
        y += 12;

        var lblSecurity = new Label
        {
            Text     = "Allowed Commands",
            Font     = new Font("Segoe UI", 10f, FontStyle.Bold),
            Location = new Point(0, y),
            AutoSize = true,
            ForeColor= Color.FromArgb(30, 41, 59)
        };
        y += 28;

        _chkAllowShutdown = new CheckBox
        {
            Text     = "Allow phone to shut down this PC",
            Checked  = true,
            AutoSize = true,
            Location = new Point(0, y),
            Font     = new Font("Segoe UI", 9.5f)
        };
        y += 28;

        _chkAllowSleep = new CheckBox
        {
            Text     = "Allow phone to put this PC to sleep",
            Checked  = true,
            AutoSize = true,
            Location = new Point(0, y),
            Font     = new Font("Segoe UI", 9.5f)
        };
        y += 28;

        _chkAllowRestart = new CheckBox
        {
            Text     = "Allow phone to restart this PC",
            Checked  = true,
            AutoSize = true,
            Location = new Point(0, y),
            Font     = new Font("Segoe UI", 9.5f)
        };
        y += 40;

        var btnSaveSettings = new Button
        {
            Text      = "💾  Save Settings",
            Location  = new Point(0, y),
            Size      = new Size(160, 36),
            BackColor = Color.FromArgb(37, 99, 235),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Font      = new Font("Segoe UI", 9.5f, FontStyle.Bold)
        };
        btnSaveSettings.FlatAppearance.BorderSize = 0;
        btnSaveSettings.Click += (_, _) =>
        {
            AppLogger.Instance.Info("Settings", $"Settings saved. Port={_nudPort.Value}, MouseSens={_nudMouseSensitivity.Value}, ScrollStep={_nudScrollStep.Value}, AllowShutdown={_chkAllowShutdown.Checked}, AllowSleep={_chkAllowSleep.Checked}, AllowRestart={_chkAllowRestart.Checked}");
            MessageBox.Show(
                "Settings saved.\n\nNote: Port changes require a server restart to take effect.",
                "Settings", MessageBoxButtons.OK, MessageBoxIcon.Information);
        };

        pnl.Controls.AddRange(new Control[]
        {
            lblNetwork, lblPort, _nudPort, lblPortNote, sep1,
            lblInput, lblMouse, _nudMouseSensitivity, lblScroll, _nudScrollStep, sep2,
            lblSecurity, _chkAllowShutdown, _chkAllowSleep, _chkAllowRestart,
            btnSaveSettings
        });
        page.Controls.Add(pnl);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  EVENT WIRING
    // ─────────────────────────────────────────────────────────────────────────

    private void WireEvents()
    {
        // Device connect / disconnect — update count + balloon tip
        _server.ClientConnected += session =>
        {
            Invoke(() =>
            {
                _lblConnectedClients.Text = $"Active Connected Devices: {_server.ActiveClientCount}";
                _trayIcon.ShowBalloonTip(2000, "Device Connected",
                    $"A device has connected. Active: {_server.ActiveClientCount}", ToolTipIcon.Info);
            });
        };

        _server.ClientDisconnected += session =>
        {
            Invoke(() =>
            {
                _lblConnectedClients.Text = $"Active Connected Devices: {_server.ActiveClientCount}";
                _trayIcon.ShowBalloonTip(2000, "Device Disconnected",
                    $"A device disconnected. Active: {_server.ActiveClientCount}", ToolTipIcon.Info);
            });
        };

        // Pairing events
        _securityManager.PairingCodeGenerated += (deviceId, pin, deviceName) =>
        {
            Invoke(() =>
            {
                _pairingExpiresAt = DateTime.UtcNow.AddSeconds(120);
                _lblPairingPin.Text  = pin;
                RefreshPairingBanner();
                _pairingCountdownTimer.Start();
            });
        };

        _securityManager.PairingCodeExpired += _ =>
        {
            Invoke(() =>
            {
                RefreshPairingBanner();
                if (!_pnlPairingAlert.Visible) _pairingCountdownTimer.Stop();
            });
        };

        _securityManager.DevicePaired += _ =>
        {
            Invoke(RefreshDevicesList);
        };

        // Live log feed
        AppLogger.Instance.LogEmitted += entry =>
        {
            if (IsDisposed || !IsHandleCreated) return;
            try
            {
                BeginInvoke(() =>
                {
                    if (_lstLogs.Items.Count > 800) _lstLogs.Items.RemoveAt(0);
                    _lstLogs.Items.Add(FormatLogEntry(entry));
                    _lstLogs.TopIndex = _lstLogs.Items.Count - 1;
                });
            }
            catch { /* form closing */ }
        };

        // Refresh IP on network adapter changes (Wi-Fi roam, VPN, hotspot)
        NetworkChange.NetworkAddressChanged += (_, _) =>
        {
            if (IsDisposed || !IsHandleCreated) return;
            try
            {
                BeginInvoke(RefreshIpLabel);
            }
            catch { }
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  LOGIC HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private void RefreshIpLabel()
    {
        var ips     = DiscoveryBeacon.GetLocalIpAddresses();
        var ipList  = ips.Count > 0 ? string.Join(", ", ips) : "127.0.0.1";
        var hotspot = DiscoveryBeacon.GetHotspotInfo();
        var hotTxt  = hotspot.IsConnected
            ? $"\n📱 Hotspot: PC {hotspot.PcIp} | Phone Gateway {hotspot.PhoneGatewayIp}"
            : "";
        _lblIpPort.Text = $"IP Address(es): {ipList}\nPort: 51234 (WebSocket)  •  51235 (Discovery){hotTxt}";
    }

    private void TickPairingCountdown()
    {
        var remaining = _pairingExpiresAt - DateTime.UtcNow;
        if (remaining <= TimeSpan.Zero)
        {
            _lblPairingTimer.Text = "Expired";
            _pairingCountdownTimer.Stop();
            RefreshPairingBanner();
            return;
        }
        _lblPairingTimer.Text = $"Expires in: {(int)remaining.TotalMinutes}:{remaining.Seconds:D2}";
    }

    private void RefreshPairingBanner()
    {
        var pairings = _securityManager.GetActivePairings();
        if (pairings.Count == 0)
        {
            _pnlPairingAlert.Visible = false;
            _pairingCountdownTimer.Stop();
            return;
        }

        _pnlPairingAlert.Visible = true;
        _lblPairingPin.Text = string.Join(" / ", pairings.Select(p => p.Pin));
    }

    private void RefreshDevicesList()
    {
        _lvDevices.Items.Clear();
        var devices = _securityManager.GetTrustedDevices();
        if (devices.Count == 0)
        {
            _lvDevices.Items.Add(new ListViewItem(new[] { "(No trusted devices paired yet)", "", "", "" }));
            return;
        }

        foreach (var d in devices)
        {
            var lvi = new ListViewItem(d.DeviceName);
            lvi.SubItems.Add(d.DeviceId);
            lvi.SubItems.Add(d.PairedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm"));
            lvi.SubItems.Add(d.LastSeen.ToLocalTime().ToString("yyyy-MM-dd HH:mm"));
            lvi.Tag = d.DeviceId;
            _lvDevices.Items.Add(lvi);
        }
    }

    private void RevokeSelectedDevice()
    {
        if (_lvDevices.SelectedItems.Count == 0) return;
        var item = _lvDevices.SelectedItems[0];
        var deviceId = item.Tag?.ToString();
        if (string.IsNullOrEmpty(deviceId) || deviceId.StartsWith("(")) return;

        var result = MessageBox.Show(
            $"Revoke device \"{item.Text}\"?\n\nThe phone will need to re-pair to connect again.",
            "Revoke Device", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);

        if (result == DialogResult.Yes)
        {
            _securityManager.RevokeDevice(deviceId);
            RefreshDevicesList();
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
            lvi.ForeColor = item.Status == "PASS"
                ? Color.FromArgb(22, 101, 52)
                : Color.FromArgb(185, 28, 28);
            _lvDiagnostics.Items.Add(lvi);
        }
    }

    private async Task StartServicesAsync()
    {
        try
        {
            await _server.StartAsync();
            _beacon.Start();
            UpdateServerRunningState(running: true);
            RefreshIpLabel();
            AppLogger.Instance.Info("UI", "Server started successfully.");
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("UI", "Failed to start server.", ex);
            UpdateServerStoppedState();
            MessageBox.Show(
                $"Failed to start server:\n{ex.Message}\n\nCheck that port 51234 is not in use and firewall rules are configured.",
                "Server Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private async Task ToggleServerAsync()
    {
        if (_server.IsRunning)
        {
            await _server.StopAsync();
            _beacon.Stop();
            UpdateServerStoppedState();
        }
        else
        {
            await StartServicesAsync();
        }
    }

    private void UpdateServerRunningState(bool running)
    {
        if (running)
        {
            _lblStatus.Text           = "Server Status: Running (Port 51234)";
            _lblStatus.ForeColor      = Color.FromArgb(40, 167, 69);
            _lblHeaderStatus.Text     = "● Running";
            _lblHeaderStatus.ForeColor= Color.FromArgb(74, 222, 128);
            _btnHeaderToggle.Text     = "Stop Server";
            _btnHeaderToggle.BackColor= Color.FromArgb(220, 53, 69);
        }
    }

    private void UpdateServerStoppedState()
    {
        _lblStatus.Text            = "Server Status: Stopped";
        _lblStatus.ForeColor       = Color.FromArgb(108, 117, 125);
        _lblHeaderStatus.Text      = "● Stopped";
        _lblHeaderStatus.ForeColor = Color.FromArgb(248, 113, 113);
        _btnHeaderToggle.Text      = "Start Server";
        _btnHeaderToggle.BackColor = Color.FromArgb(40, 167, 69);
    }

    private static string FormatLogEntry(LogEntry entry)
    {
        var level = entry.Level.ToString().ToUpperInvariant()[..1]; // D / I / W / E
        return $"[{entry.Timestamp:HH:mm:ss}] [{level}] [{entry.Component}] {entry.Message}";
    }

    private void CopyPairingPinToClipboard()
    {
        var firstPin = _securityManager.GetActivePairings().FirstOrDefault()?.Pin;
        if (!string.IsNullOrEmpty(firstPin))
        {
            System.Windows.Forms.Clipboard.SetText(firstPin);
            _trayIcon.ShowBalloonTip(1500, "PIN Copied", $"Pairing PIN {firstPin} copied to clipboard.", ToolTipIcon.Info);
        }
        else
        {
            MessageBox.Show("No active pairing session right now.", "Universal PC Remote™ by Aniket Akal",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void BringToForeground()
    {
        Show();
        WindowState = FormWindowState.Normal;
        BringToFront();
        Activate();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  STARTUP / FIREWALL / LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────────

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
                if (string.IsNullOrWhiteSpace(executablePath) ||
                    !executablePath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(
                        "Startup can be enabled only from the published Companion executable.");
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
            _chkStartWithWindows.Checked  = !_chkStartWithWindows.Checked;
            _suppressStartupSettingUpdate = false;
            AppLogger.Instance.Error("Startup", "Failed to update automatic startup setting.", ex);
            MessageBox.Show(ex.Message, "Universal PC Remote™ by Aniket Akal",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void ConfigureFirewall()
    {
        try
        {
            var exePath = Environment.ProcessPath ?? Application.ExecutablePath;
            var script  = $@"@echo off
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
                FileName         = "cmd.exe",
                Arguments        = $"/c \"\"{tempBat}\"\"",
                Verb             = "runas",
                UseShellExecute  = true,
                WindowStyle      = System.Diagnostics.ProcessWindowStyle.Hidden
            };
            var proc = System.Diagnostics.Process.Start(psi);
            proc?.WaitForExit(8000);

            try { File.Delete(tempBat); } catch { }

            // Verify: query netsh to confirm rules exist
            using var check = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName               = "netsh",
                Arguments              = "advfirewall firewall show rule name=\"Universal PC Remote (TCP 51234)\"",
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                CreateNoWindow         = true
            });
            check?.WaitForExit(3000);
            var rulesExist = (check?.ExitCode ?? 1) == 0;

            if (rulesExist)
            {
                MessageBox.Show(
                    "Windows Defender Firewall rules have been successfully registered!\n\n• TCP Port 51234 (WebSocket Commands)\n• UDP Port 51235 (Discovery Beacon)\n• Application Exemption",
                    "Firewall Configured", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            else
            {
                MessageBox.Show(
                    "Firewall rules may not have been applied correctly.\n\nPlease approve the Administrator prompt, or run scripts\\setup_firewall.bat as Administrator manually.",
                    "Firewall Setup", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to configure firewall: {ex.Message}\n\nMake sure to approve the Administrator prompt or run scripts\\setup_firewall.bat.",
                "Firewall Setup", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        _ = StartServicesAsync();

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
            _pairingCountdownTimer.Stop();
            _beacon.Dispose();
            _server.StopAsync().GetAwaiter().GetResult();
            base.OnFormClosing(e);
        }
    }
}
