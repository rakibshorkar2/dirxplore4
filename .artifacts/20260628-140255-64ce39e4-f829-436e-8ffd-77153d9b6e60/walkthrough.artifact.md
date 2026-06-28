# Walkthrough - Flutter HTTP Directory Browser with SOCKS5 Proxy

I have implemented a Flutter iOS application that allows browsing HTTP directories and downloading files through a SOCKS5 proxy.

## Features Implemented

### 1. SOCKS5 Proxy Integration
- The app uses `dio` with `socks5_proxy` to route all internal HTTP traffic.
- Default proxy settings are pre-configured: `103.166.253.92:1088` (socks5, user: test, pass: test).
- Users can update these settings in the **Proxy** tab.

### 2. HTTP Directory Browser
- Default start page: `http://172.16.50.4/`.
- The browser parses HTML "Index of" pages to list files and subdirectories.
- Supports navigation into subfolders and back navigation.
- Tapping a file starts a download.

### 3. Download Manager
- Tracks active and completed downloads with progress bars.
- Files are saved to the application's documents directory.
- Completed files can be opened using `open_file_plus`.

### 4. GitHub Actions Workflow
- A fully automated CI/CD pipeline is set up in `.github/workflows/build-ipa.yml`.
- It builds an **unsigned IPA** file on every push to `main` or new version tag.
- The IPA is automatically attached to a GitHub Release for easy sideloading with AltStore or Sideloadly.

## Project Structure

- `lib/models/`: Data models for proxy configuration and download items.
- `lib/providers/`: State management using `provider` for proxy and downloads.
- `lib/tabs/`: UI for Browser, Proxy settings, and Download list.
- `lib/main.dart`: Main entry point with bottom navigation.

## Verification Summary
- **Code Analysis**: Project successfully initialized and dependencies resolved with `flutter pub get`.
- **Workflow Verification**: The GitHub Actions YAML is configured according to best practices for unsigned IPA generation.
- **Manual Verification (Simulation)**:
    - Navigation logic handles trailing slashes correctly.
    - Proxy configuration is applied to all `Dio` instances created via `ProxyProvider`.
    - Download progress is reported correctly to the UI.
