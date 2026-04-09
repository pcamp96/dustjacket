# Repository Guidelines

## Project Structure & Module Organization
`Dustjacket/` contains the single iOS app target. Use `App/` for the entry point and root navigation, `Models/` for domain types, `Services/` for API, keychain, and ISBN lookup code, `Managers/` for shared `@MainActor` state, `Persistence/` for SwiftData cache models, `Views/` and `Views/Components/` for SwiftUI UI, `Wizard/` for first-run list setup, and `Theme/` for reusable styling. `project.yml` is the source of truth for project settings; regenerate `Dustjacket.xcodeproj` after editing it.

## Build, Test, and Development Commands
`open Dustjacket.xcodeproj` opens the app in Xcode.

`xcodegen generate` rebuilds the Xcode project from `project.yml`.

`xcodebuild -project Dustjacket.xcodeproj -scheme Dustjacket -configuration Debug build` runs a CLI build for the shared scheme.

`xcodebuild -project Dustjacket.xcodeproj -scheme Dustjacket -destination 'platform=iOS Simulator,name=iPhone 17' build` validates simulator builds before pushing.

Run scanner changes on a physical device as well; camera and barcode flows are not fully covered by simulator testing.

## Coding Style & Naming Conventions
Use Swift 6 conventions already present in the codebase: 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and functions, and `// MARK:` sections in larger files. Keep views thin: reusable UI belongs in `Views/Components/`, while API, queueing, and persistence logic stays in `Services/`, `Managers/`, or `Persistence/`. Follow existing SwiftUI-first patterns and only introduce UIKit wrappers when platform APIs require them.

## Testing Guidelines
No XCTest target is committed today. Validate changes with focused simulator runs plus on-device checks for login, scanning, offline mutation queueing, and SwiftData-backed screens. When adding non-trivial logic to services or managers, create an XCTest target and name files `FeatureNameTests.swift` so coverage can grow with the codebase.

## Commit & Pull Request Guidelines
Recent commits use short, imperative subjects with context when useful, for example `Edition selection: browse and pick specific book editions` and `Wire all stubbed mutations`. Keep commits narrowly scoped and explain behavior changes, not implementation noise. PRs should summarize user-visible impact, list manual verification steps, link related issues, and include screenshots for UI changes.

## Security & Configuration Tips
Do not commit Hardcover API tokens or personal account data. Tokens are entered through the app and stored in Keychain; keep sample values out of code, screenshots, and logs.
