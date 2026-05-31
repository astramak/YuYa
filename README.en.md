# YuYa

<p align="center">
  <img src="Docs/assets/app-icon.png" width="128" height="128" alt="YuYa app icon">
</p>

<p align="center">
  <strong>Native macOS shell for web music services.</strong><br>
  Yandex Music, YouTube Music, Zvuk, and any custom web player in one persistent app window.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS-lightgrey">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-orange">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20WebKit-blue">
  <img alt="License" src="https://img.shields.io/badge/license-GPL--3.0-green">
</p>

YuYa is a small macOS music player wrapper built with SwiftUI, AppKit, and WebKit. It keeps each music service in its own persistent `WKWebView`, so switching between services does not reset the page, queue, login session, or current screen.

The app does not download, extract, proxy, or bypass protected audio streams. It displays official web players and connects playback metadata to macOS media controls.

## Screenshots

<p align="center">
  <img src="Docs/assets/screenshot-yandex.png" width="860" alt="YuYa main window with Yandex Music">
</p>

<p align="center"><em>Main window: native toolbar, persistent service tabs, and the official web player inside YuYa.</em></p>

<p align="center">
  <img src="Docs/assets/screenshot-youtube.png" width="860" alt="YouTube Music inside YuYa">
</p>

<p align="center"><em>YouTube Music runs as a separate tab and keeps its state while switching services.</em></p>

<table>
  <tr>
    <td width="50%">
      <img src="Docs/assets/screenshot-add-service.png" alt="Adding a custom service">
    </td>
    <td width="50%">
      <img src="Docs/assets/screenshot-settings.png" alt="YuYa settings">
    </td>
  </tr>
  <tr>
    <td align="center"><em>Adding a custom service</em></td>
    <td align="center"><em>App settings</em></td>
  </tr>
</table>

<table>
  <tr>
    <td width="75%">
      <img src="Docs/assets/screenshot-about.png" alt="YuYa about screen">
    </td>
    <td width="25%" align="center">
      <img src="Docs/assets/screenshot-control-center.png" width="160" alt="macOS media controls">
    </td>
  </tr>
  <tr>
    <td align="center"><em>About screen and legal notice</em></td>
    <td align="center"><em>macOS media controls</em></td>
  </tr>
</table>

<p align="center">
  <img src="Docs/assets/screenshot-yandex-alt.png" width="860" alt="YuYa with Yandex Music in another playback state">
</p>

## Features

- Native macOS window chrome with compact toolbar controls.
- Persistent tabs for each service: switch without recreating web views.
- Built-in defaults for YouTube Music and Yandex Music.
- Custom services: add a display name and URL in Settings.
- Favicon loading for service tabs and playback indicators.
- macOS Control Center integration through `MPNowPlayingInfoCenter`.
- Remote media commands through `MPRemoteCommandCenter`.
- One active playback source: starting playback in one service pauses the others.
- Cookies, sessions, and last URLs are stored through WebKit's persistent data store.
- Russian and English interface language options.

## Supported Services

Built in:

- YouTube Music
- Yandex Music

Known custom-service use cases:

- Zvuk
- Other web music players with ordinary browser playback

Custom services are best-effort. If a service blocks embedded WebKit browsers, uses unusual popup auth, or relies on browser-specific DRM behavior, it may need service-specific handling.

## Architecture

YuYa is intentionally small and native:

- `SwiftUI` for the app shell, settings, and toolbar controls.
- `AppKit` for window lifecycle and native `NSToolbar` behavior.
- `WKWebView` for isolated persistent service tabs.
- JavaScript bridge for playback snapshots, capabilities, and remote commands.
- `MediaPlayer` APIs for macOS Now Playing and media keys.

The main state is owned by `AppModel`, while each service is represented by `ServiceWebViewModel`.

## Build and Distribution

Requirements:

- macOS
- Xcode with Swift 5 support

Debug build for development:

```sh
xcodebuild build \
  -scheme YuYa \
  -configuration Debug \
  -destination 'platform=macOS'
```

Run tests:

```sh
xcodebuild test \
  -scheme YuYa \
  -destination 'platform=macOS'
```

Unsigned Release build for local testing:

```sh
xcodebuild build \
  -scheme YuYa \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

The built app will be here:

```sh
build/DerivedData/Build/Products/Release/YuYa.app
```

This is useful for local testing, but it is not suitable for public distribution. macOS will warn users about an unsigned app.

### Developer ID release

Distribution outside the Mac App Store requires an Apple Developer account, a `Developer ID Application` certificate, and configured `notarytool` credentials.

Archive:

```sh
xcodebuild archive \
  -scheme YuYa \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/YuYa.xcarchive \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Export signed `.app`:

```sh
xcodebuild -exportArchive \
  -archivePath build/YuYa.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist Packaging/ExportOptions.DeveloperID.plist
```

DMG:

```sh
hdiutil create \
  -volname "YuYa" \
  -srcfolder build/export/YuYa.app \
  -ov \
  -format UDZO \
  build/YuYa.dmg
```

Notarization:

```sh
xcrun notarytool submit build/YuYa.dmg \
  --keychain-profile "notarytool-profile" \
  --wait

xcrun stapler staple build/YuYa.dmg
```

Create the notarization profile if needed:

```sh
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

## Notes

- Safari passwords and Safari website sessions are not shared with `WKWebView` apps. YuYa has its own WebKit storage.
- Some login providers may still decide that embedded browsers are not allowed.
- The app keeps playback alive when the main window is closed; quitting the app stops everything.
- macOS media metadata depends on what the web player exposes through Media Session or standard HTML media elements.

## Legal

YuYa is not affiliated with, endorsed by, or sponsored by Yandex, Google, YouTube, Spotify, Zvuk, or any other supported service. All trademarks, service names, logos, and media content belong to their respective owners.

YuYa does not download, extract, decrypt, proxy, or bypass protected audio streams. It only embeds official web players in a native macOS wrapper.
