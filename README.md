# SpeedBar

<p align="center">
  <img src="SpeedBar/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="SpeedBar Icon" width="128" height="128">
</p>

<p align="center">
  <strong>A lightweight macOS menu bar app for network quality measurement</strong>
</p>

<p align="center">
  🇬🇧 🇹🇷 🇩🇪 🇪🇸 🇫🇷 🇮🇹 🇨🇳 🇯🇵 🇮🇳 🇳🇱
</p>

---

**SpeedBar** is a lightweight macOS menu bar application that measures your network quality using Apple's built-in `networkQuality` tool. Get accurate, on-demand network performance metrics without leaving your workflow.

## ✨ Features

- 📊 **Real-Time Speed Display** - Watch download/upload speeds update live during measurement
- 🖥️ **Menu Bar Integration** - Lives in your macOS menu bar for quick access
- 🔄 **On-Demand Testing** - User-triggered measurements only, no background polling
- 💾 **Smart Caching** - Results cached for 10 minutes to avoid redundant tests
- 🌍 **10 Languages** - English, Turkish, German, Spanish, French, Italian, Chinese, Japanese, Hindi, Dutch
- 🎌 **Flag-Based Language Selection** - Quick language switch with country flags
- 🌓 **Theme Support** - Fully supports macOS Light and Dark modes
- 🚀 **Auto-Launch** - Optional automatic startup when macOS boots
- ✨ **Animated UI** - Smooth gradient animations during measurement

## 🔧 Why networkQuality?

SpeedBar uses `/usr/bin/networkQuality`, Apple's official network quality measurement tool introduced in macOS Monterey. This tool provides:

- **Responsiveness (RPM)** - Measures the network's ability to handle traffic under load
- **Capacity Measurements** - Accurate upload and download speed testing
- **Latency Metrics** - Idle and loaded latency measurements
- **No Third-Party Dependencies** - Uses Apple's CDN infrastructure for testing

Unlike traditional speed tests that only measure raw bandwidth, `networkQuality` provides a more complete picture of your network's real-world performance.

## 💻 System Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 13.0 (Ventura) or later |
| Xcode (for building) | 15.0 or later |
| Network | Active internet connection |

## 📥 Installation

### Pre-built DMG

1. Download the latest `.dmg` file from the [Releases](../../releases) page
2. Open the DMG and drag SpeedBar to your Applications folder
3. Launch SpeedBar from Applications

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/SpeedBar.git
cd SpeedBar

# Open in Xcode
open SpeedBar.xcodeproj

# Or build from command line
xcodebuild -project SpeedBar.xcodeproj -scheme SpeedBar -configuration Release
```

## 🔐 macOS Permissions

### App Sandbox Disabled
SpeedBar runs with the App Sandbox disabled to execute the `networkQuality` command-line tool. This is necessary because:
- The app needs to spawn a child process (`/usr/bin/networkQuality`)
- Network measurement requires unrestricted network access

### Login Items (Optional)
If you enable "Launch at Login", SpeedBar uses `SMAppService` to register itself as a login item. This permission is managed through:
- System Settings → General → Login Items

## ⚙️ How It Works

### Measurement Lifecycle

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Start Button   │ ──▶ │  Live Speeds     │ ──▶ │  Final Results  │
│  (Idle State)   │     │  (Measuring...)  │     │  (Cached 10min) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │                         │
                               ▼                         ▼
                        Real-time download        "Start Again"
                        & upload display          button available
```

### What's Measured

| Metric | Description |
|--------|-------------|
| Download Speed | Maximum download capacity (Mbps/Gbps) |
| Upload Speed | Maximum upload capacity (Mbps/Gbps) |
| Download Responsiveness | RPM (Round-trips Per Minute) under download load |
| Upload Responsiveness | RPM under upload load |
| Idle Latency | Network latency with no load (ms) |

### Error Handling

SpeedBar handles errors gracefully:
- **No Internet** - Shows clear "No connection" message
- **Binary Missing** - Silently resets to initial state
- **Timeout/Parse Error** - Silently resets to initial state
- **Partial Data** - Shows available metrics, hides unavailable ones

## 🌍 Localization

SpeedBar supports **10 languages** with instant switching:

| Flag | Language | Code | Status |
|------|----------|------|--------|
| 🇬🇧 | English | `en` | ✅ Complete |
| 🇹🇷 | Türkçe | `tr` | ✅ Complete |
| 🇩🇪 | Deutsch | `de` | ✅ Complete |
| 🇪🇸 | Español | `es` | ✅ Complete |
| 🇫🇷 | Français | `fr` | ✅ Complete |
| 🇮🇹 | Italiano | `it` | ✅ Complete |
| 🇨🇳 | 中文 | `zh` | ✅ Complete |
| 🇯🇵 | 日本語 | `ja` | ✅ Complete |
| 🇮🇳 | हिन्दी | `hi` | ✅ Complete |
| 🇳🇱 | Nederlands | `nl` | ✅ Complete |

**Language selection:**
1. Open Settings (gear icon)
2. Click on your preferred language flag
3. UI updates instantly - no restart required!

## 🏗️ Architecture

```
SpeedBar/
├── SpeedBarApp.swift              # App entry point
├── AppDelegate.swift              # Menu bar & popover management
├── Info.plist                     # App configuration
├── Localizable.xcstrings          # Localization strings (10 languages)
├── generate_app_icon.swift        # App icon generator script
├── build_dmg.sh                   # DMG packaging script
├── Services/
│   ├── NetworkQualityService.swift    # Process execution & parsing
│   ├── LocalizationManager.swift      # Language handling
│   └── AutoLaunchManager.swift        # SMAppService integration
├── ViewModels/
│   └── MeasurementViewModel.swift     # State management & caching
└── Views/
    ├── PopoverView.swift              # Main measurement UI
    └── SettingsView.swift             # Settings panel
```

### Design Patterns

- **MVVM Architecture** - Clean separation of concerns
- **Combine Framework** - Reactive state management
- **@MainActor** - Thread-safe UI updates
- **ObservableObject** - SwiftUI integration

## 🔒 Privacy

SpeedBar respects your privacy:

| ✅ | Privacy Feature |
|----|-----------------|
| ✅ | No data collection |
| ✅ | No analytics or tracking |
| ✅ | No network requests except `networkQuality` tests |
| ✅ | All data stored locally |
| ✅ | Open source for verification |

## ⚠️ Known Limitations

1. **macOS Only** - Uses macOS-specific `networkQuality` tool
2. **No Background Measurements** - By design, all measurements are user-triggered
3. **10-Minute Cache** - Cannot disable or adjust cache duration
4. **Unsigned Builds** - Pre-built DMGs may require right-click → Open for Gatekeeper

## 📄 License

This project is available under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Apple for the `networkQuality` tool
- SF Symbols for the beautiful icons
- The macOS developer community

---

<p align="center">
  Made with ❤️ for the macOS community
</p>

<p align="center">
  <sub>SpeedBar v1.0</sub>
</p>
