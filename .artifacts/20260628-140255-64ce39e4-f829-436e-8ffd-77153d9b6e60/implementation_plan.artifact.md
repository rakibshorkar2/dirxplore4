# Implementation Plan - Flutter HTTP Directory Browser with SOCKS5 Proxy

Create a Flutter app for iOS that browses HTTP directories, downloads files, and routes all traffic through a SOCKS5 proxy. Includes GitHub Actions for unsigned IPA generation.

## User Review Required

> [!IMPORTANT]
> - **SOCKS5 Support**: All HTTP traffic (browsing and downloading) will be routed through the SOCKS5 proxy using `dio` and `socks5_proxy`. Note that this only applies to traffic within the app, not system-wide.
> - **Unsigned IPA**: The GitHub Actions workflow will produce an unsigned IPA. This requires sideloading (e.g., via AltStore) to install on a non-jailbroken iPhone.
> - **HTTP Directory Parsing**: The browser will parse standard HTML "Index of" pages (common in Apache/Nginx). If the server uses a different layout, parsing might need adjustments.

## Proposed Changes

### Dependencies
Update `pubspec.yaml` with necessary packages.
- `dio`: HTTP client.
- `socks5_proxy`: SOCKS5 support for Dart's `HttpClient`.
- `html`: To parse directory index HTML.
- `path_provider`: For file storage paths.
- `provider`: State management for proxy settings and download tasks.
- `intl`: For date/size formatting.
- `url_launcher`: To open downloaded files (if possible).
- `yaml`: To parse proxy configurations.
- `open_file_plus`: To open files.

---

### Core Components

#### `proxy_provider.dart` [UPDATED]
- Manages the list of proxies and the currently selected one.
- Parses YAML configuration strings to populate the proxy list.
- Provides a method to create a `Dio` instance configured with the active SOCKS5 settings.

#### `browser_tab.dart` [NEW]
- Default URL: `http://172.16.50.4/`
- Fetches HTML content, parses links, and displays them in a `ListView`.
- Handles navigation (folder tapping).
- Initiates downloads on file tapping.

#### `proxy_tab.dart` [UPDATED]
- Includes a text field/dialog for pasting YAML configurations.
- Lists imported proxies with a selection mechanism.
- Retains manual editing for the currently selected proxy.

#### `download_tab.dart` [NEW]
- List of active and completed downloads.
- Progress bars for active downloads.
- Options to open or delete completed files.

---

### UI & Navigation

#### `main.dart`
- Sets up `MultiProvider` for state management.
- Implements `BottomNavigationBar` with three tabs: Browser, Proxy, Download.

---

### Infrastructure

#### `.github/workflows/build-ipa.yml` [NEW]
- Triggered on push to `main` and manually.
- Runs `flutter build ios --release --no-codesign`.
- Packages `Runner.app` into `Payload/` and zips to `.ipa`.
- Creates a GitHub Release with the version number from `pubspec.yaml` or a git tag.

## Verification Plan

### Automated Tests
- No specific automated tests planned, but will verify buildability in CI.

### Manual Verification
- **Proxy Functionality**: Verify that browsing only works when the proxy settings are correct (or test against a public SOCKS5 proxy if `103.166.253.92` is not reachable from the agent's environment).
- **Directory Browsing**: Navigate into folders at `http://172.16.50.4/`.
- **Downloading**: Download a small file and verify its appearance in the Download tab.
- **IPA Build**: Verify that the GitHub Action successfully produces an `.ipa` artifact.
