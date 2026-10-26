# Aura

![SceneBox on Mac and iPhone](website/images/mac-detail.png)

# Aura

A modern, high-performance media streaming and BitTorrent/HTTP client for iOS, iPadOS, tvOS, and macOS (Catalyst), built entirely in SwiftUI.

---

## Important Disclaimer

Aura is a media player and BitTorrent/HTTP client utility. It does not provide, host, index, upload, store, or distribute any media content, and it has no affiliation with any content source.

- All catalog metadata, stream listings, and media files are retrieved from third-party services and peers configured or connected by the user. These services are independent of Aura, are not operated, controlled, endorsed, or reviewed by the author, and may be changed or removed at any time.
- Users are solely responsible for the content they choose to access, for ensuring they have the legal right to do so, and for complying with all applicable copyright laws in their jurisdiction. The author does not encourage, condone, or accept responsibility for any infringing use.
- The software is provided "as is", without warranty of any kind, for personal and lawful use only. See [LICENSE](https://github.com/Riolu69/Aura/blob/main/LICENSE).

If you are a rights holder and believe a third-party source accessible through this software infringes your rights, please contact that source directly, as the author has no control over it.

---

## Architecture & Tech Stack

- **Streams**: Sourced from Stremio-compatible addons, played via a vendored `libtorrent` engine and a local HTTP server feeding VLC. Debrid-cached releases stream directly over HTTPS.
- **Project Structure**:
  - `WatchBox/App` – App entry point, root navigation, and routing.
  - `WatchBox/Core/Catalog` – Addon queries, release parsing, and TMDB integration.
  - `WatchBox/Core/TorrentEngine` – Libtorrent session wrapper and local streaming server.
  - `WatchBox/Features` – UI screens (Home, Search, Detail, Player, Library, Profiles, Downloads, Settings).
  - `WatchBox/Shared` – Shared models, reusable UI components, and theme configurations.
  - `LibTorrent` – Prebuilt `LibtorrentEngine.xcframework` (libtorrent 2.0.11 + OpenSSL) with its ObjC++ wrapper.
  - `scripts` – Automation scripts for release packaging (`release-mac.sh`, `export-ipa.sh`).

---

## Installation & Builds

### Get the IPA (No Mac Required)
Every push to the repository automatically triggers a GitHub Actions workflow (`.github/workflows/build-ipa.yml`) to build an unsigned IPA:
- Sign and install it using **ESing, Sideloadly, AltStore, SideStore, or TrollStore**.

### Building Locally
1. **Requirements**: Xcode 26.4 or later (SwiftVLC requires Swift 6.3). Swift Package Manager dependencies resolve automatically on first open.
2. **Device Builds**: Requires an Apple Developer account; configure your `DEVELOPMENT_TEAM` in Xcode.
3. **Engine**: The libtorrent engine is prebuilt and linked via `xcframework`. 

---

## Features & Data Privacy

- **No Server Accounts**: There are no external accounts required. User profiles (up to 5, with avatars), watch history, and watchlists are stored securely on the device per profile. Debrid and TMDB API keys remain isolated in the device Keychain.
- **Smart Downloads**: 
  - Manage individual episodes or entire season packs seamlessly. Concurrent downloads run side-by-side up to the configured limit.
  - Interrupted downloads automatically resume on app relaunch.
  - **Background Downloads**: To prevent iOS from suspending tasks, Aura uses a silent audio session (`Profile` → `Downloads` → *"Keep downloading in background"*). On supported iOS versions, a Live Activity tracks progress.

---

## Release & Debug Automation

### Release Scripts
- `scripts/release-mac.sh 1.0.0` — Signed + notarized macOS DMG
- `scripts/export-ipa.sh 1.0.0` — Unsigned iOS IPA for sideloading
- `scripts/export-ipa.sh 1.0.0 tvos` — Unsigned tvOS IPA for sideloading

### Debug Launch Flags
- `-WBAutoStreamMagnet '<magnet>'` — Start streaming a specific magnet link instantly at launch.
- `-WBAutoStreamFileIndex N` — Select a specific file inside a multi-file torrent pack.
- `-WBAutoSeekScript '40:+300,80:-120'` — Run scripted timeline seeks for testing.

*(Metrics are logged to `Documents/diagnostics/metrics.jsonl` in Debug builds).*

---

## Contact & Support

Questions, bug reports, and feature ideas are always welcome:
- **Telegram**: [@PlainPerson](https://t.me/PlainPerson)
- **GitHub Issues**: Open an issue on this repository for bug reports or feature requests.

---

## License

Personal, non-commercial use only. You may read the source code and build it for your own personal use; you may not sell it, redistribute it, or use it in any commercial product or service. See [LICENSE](https://github.com/Riolu69/Aura/blob/main/LICENSE).
