# CursorBar

Lightweight, open-source macOS menu bar utility for tracking Cursor AI Fast Requests, token consumption, and usage-based spending.

## Requirements

- macOS 14.0+
- Xcode 15.0+

## Build & Run

### Makefile (recommended)

```bash
cd cursorbar
make run              # build, package, and open CursorBar.app
make build-release    # release build only
make dmg              # release app + dist/CursorBar-<version>.dmg
make test             # unit + integration tests + launch smoke check
make bootstrap        # seed ~/.cursorbar/config.toml
make icons            # regenerate app/menu bar icons
make help             # all targets
```

Optional live API test (requires a real session token):

```bash
CURSORBAR_SESSION_TOKEN="your-token" make test
```

### Xcode

```bash
open CursorBar.xcodeproj
```

Select your **Development Team** under Signing & Capabilities, then build and run (`⌘R`).

## Configuration

Non-secret settings can be described in `config.toml`. Copy the template:

```bash
mkdir -p ~/.cursorbar
cp config.toml.example ~/.cursorbar/config.toml
```

Or point the app at a custom file:

```bash
export CURSORBAR_CONFIG=/path/to/config.toml
```

Session tokens stay in the macOS Keychain — never put them in `config.toml`.

## Authentication

CursorBar does not use a public API key. On first launch:

1. Sign in at [cursor.com](https://cursor.com)
2. Open DevTools → **Application** → **Cookies**
3. Copy the value of `WorkosCursorSessionToken`
4. Paste it into the onboarding sheet or **Preferences**

The token is stored in the macOS Keychain (`kSecClassGenericPassword`) and never written to plaintext files.

## Architecture

```
CursorBar/
├── App/              # @main entry + NSApplicationDelegate
├── Controllers/      # NSStatusItem + NSPopover (AppKit)
├── Models/           # UsageResponse, gauge status, polling config
├── Services/         # Keychain, API client, polling, sleep monitor
├── Views/            # SwiftUI popover, preferences, onboarding
└── Resources/        # Info.plist (LSUIElement), Assets
```

| Layer | Responsibility |
|-------|----------------|
| `StatusBarController` | Native menu bar anchor via `NSStatusItem`, hosts SwiftUI in `NSPopover` |
| `UsageStore` | Observable state, timed polling, sleep-aware pause/resume |
| `CursorAPIService` | `GET https://www.cursor.com/api/usage` with session cookie |
| `KeychainService` | Secure `WorkosCursorSessionToken` storage |
| `SleepMonitor` | Pauses polling on `NSWorkspace.willSleepNotification` |

## Gauge Colors

| Status | Condition |
|--------|-----------|
| Green | > 20% fast-request quota remaining |
| Orange | < 20% quota remaining, or ≥ 80% optional spend used |
| Red | < 50 fast requests remaining |
| Grey ⚠️ | Session expired or network error |

## Preferences

- Refresh interval: 5 / 15 / 30 minutes
- Manual **Sync Now** in the popover header
- Toggle menu bar display: remaining requests vs. dollar spend

## API Note

The `/api/usage` endpoint and JSON schema are based on the product spec. If Cursor changes their dashboard API, update `UsageResponse` in `Models/UsageData.swift` and `CursorAPIService.swift` accordingly.

## Documentation

- [User Guide](docs/USER_GUIDE.md)
- [Functional Specification (SPEC)](docs/SPEC.md)

## License

Open source — see repository license.
