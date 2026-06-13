# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Native Apple Silicon (arm64) support for macOS 12+ — the plugin no longer
  requires Rosetta 2.
- New cross-platform build/pack pipeline (`build.sh`) that runs on macOS and
  packages plugins with Elgato's official CLI (`@elgato/cli`), replacing the
  Windows-only `export.ps1` / `DistributionTool.exe` flow.
- macOS executable is now self-contained and ad-hoc codesigned so Gatekeeper
  allows the unsigned arm64 binary to launch.

### Changed

- Upgraded the project from .NET Core 3.1 to .NET 8 (LTS).
- Updated runtime identifiers to the .NET 5+ syntax: `win-x64`, `osx-arm64`,
  `osx-x64`.
- Bumped dependencies: StreamDeck-Tools 2.6.0 → 6.4.0 (BarRaider),
  Newtonsoft.Json 12.0.3 → 13.0.4, Microsoft.Extensions.Configuration\* 3.1.4 →
  8.0.x, Fleck 1.1.0 → 1.2.0.
- Adapted the action classes to the StreamDeck-Tools v6 API (`KeypadBase`,
  `ISDConnection`).
- Manifest updated for the current Stream Deck 7.x schema (added `UUID`, 4-part
  `Version`, per-platform `OS` / `CodePath`).

### Fixed

- Connection no longer drops (WebSocket close `1011`) every time the editor
  sends a `ChangeActiveSessionMessage` (i.e. on every VS Code focus change).
  The shared connection map is now a thread-safe `ConcurrentDictionary`, an
  exception thrown from a Fleck message callback can no longer tear down the
  socket, and message sends are wrapped so a send fault is logged instead of
  surfacing as an unobserved task exception. This also restores button presses,
  which previously had no stable active session to deliver to.
- Fleck's internal logging is now routed into the plugin log, so connection
  errors are visible in `pluginlog.log`.

### Removed

- `App.config` (unused under .NET Core / .NET 8).
- Windows-only build helpers `export.ps1`, `postbuild.ps1` and
  `tools/DistributionTool.exe`.

## [5.1.3] - 2020-05-15

### Changed

- Fixed macOS connection lost

## [5.1.2] - 2020-05-28

### Added

- Added open folder action.

### Changed

- Fixed macOS configuration default values loading.

## [4.1.2] - 2020-03-02

### Added

- Mac OS support

## [3.1.2] - 2020-02-24

### Added

- Multi-action support

## [3.0.2] - 2020-01-01

### Added

- Insert snippet key

### Changed

- Auto install dependencies

## [2.0.2] - 2019-12-09

### Added

- Change language key

## Changed

- "Execute Command" key now support arguments.