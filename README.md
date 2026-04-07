# Dustjacket

A native iOS app for managing your book collection through [Hardcover](https://hardcover.app) — the modern alternative to Goodreads.

Dustjacket brings your Hardcover library to your pocket with barcode scanning, format-specific collection tracking, and offline support.

---

## Features

### Barcode Scanner
Scan book barcodes with your camera to instantly look up editions on Hardcover. Includes OCR fallback for inner-cover ISBNs and manual search as a last resort.

### 8-Format Collection System
Track your books across 8 format-specific lists, automatically created on your Hardcover account:

| Owned | Want |
|-------|------|
| Hardback | Hardback |
| Paperback | Paperback |
| eBook | eBook |
| Audiobook | Audiobook |

### Full Library Management
- **Home** — Currently reading, recently added, quick stats
- **Library** — Filter by ownership (Owned/Want) and format, infinite-scroll grid
- **Explore** — Trending books this week, featured lists
- **Search** — Full-text search across books, authors, series, and lists

### Avatar Menu
Tap your profile avatar to access:
- **Goals** — Reading goal tracking
- **Lists** — All your Hardcover lists (not just DJ lists)
- **Activity** — Social feed and personal reading history
- **Stats** — Books read, pages, reading status breakdown
- **Social** — Following and followers
- **Settings** — Token management, list remapping, sync status

### Offline Support
- All data cached locally via Swift Data
- Mutations queued when offline, executed sequentially on reconnect
- Visual sync indicator when pending writes exist

---

## Requirements

- iOS 26.0+
- Xcode 26+
- A [Hardcover](https://hardcover.app) account with an API token

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/pcamp96/dustjacket.git
   ```

2. Open in Xcode
   ```bash
   open Dustjacket.xcodeproj
   ```

3. Set your signing team in **Signing & Capabilities**

4. Build and run on your device (camera features require a physical device)

5. Get your Hardcover API token:
   - Go to [hardcover.app](https://hardcover.app)
   - Navigate to **Account Settings** → **Hardcover API**
   - Copy the token (without the "Bearer" prefix)

6. Paste the token in Dustjacket's login screen

The app will validate your token, run the list setup wizard to create or match your 8 DJ lists, and drop you into the Home tab.

## Architecture

| Layer | Description |
|-------|-------------|
| **Services** | `GraphQLClient` (raw URLSession + Codable, rate-limited at 55 req/min), `HardcoverService` (protocol-based), `KeychainManager` |
| **Managers** | Singleton `@MainActor` ObservableObjects — `LibraryManager`, `ScannerManager`, `SyncManager`, `MutationQueue`, etc. |
| **Models** | Domain structs (`Book`, `Edition`, `DJList`) decoupled from API response models (`HardcoverBook`, `HardcoverEdition`) |
| **Persistence** | Swift Data `@Model` classes for offline cache (`CachedBook`, `CachedEdition`, `ListMapping`, `PendingMutation`) |
| **Views** | SwiftUI views organized by feature — no storyboards, no UIKit (except VisionKit scanner wrapper) |
| **Theme** | `DustjacketTheme` (Hardcover-inspired dark palette) + `GlassModifiers` (iOS 26 Liquid Glass preparation) |

### Key Design Decisions

- **No Apollo** — Raw URLSession + Codable matches project conventions. Swift Data provides the same reactive cache benefits.
- **Optimistic UI** — Books appear in your library instantly after scanning; mutations queue in the background.
- **Sequential Mutations** — Hardcover's API errors on concurrent list writes. `MutationQueue` serializes all mutations with 300ms delays.
- **Protocol-Based Services** — `HardcoverServiceProtocol` allows mock injection for testing and provides a single point of change if the beta API breaks.

## Project Structure

```
Dustjacket/
├── App/            Entry point, tab layout, avatar menu
├── Models/         Domain models (Book, Edition, DJList, BookFormat, etc.)
├── Services/       GraphQL client, Hardcover API, Keychain, ISBN lookup
├── Managers/       Singleton state managers (Library, Scanner, Sync, etc.)
├── Views/          All SwiftUI views organized by feature
├── Wizard/         First-launch list setup flow
├── Persistence/    Swift Data models for offline cache
└── Theme/          Color palette and Liquid Glass modifiers
```

## Tech Stack

- **UI**: SwiftUI (iOS 26), Liquid Glass
- **Networking**: URLSession + GraphQL (Hardcover API)
- **Persistence**: Swift Data
- **Scanning**: VisionKit (DataScanner), Vision (OCR)
- **Auth**: iOS Keychain
- **Project Gen**: [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## License

Private project. All rights reserved.
