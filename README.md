# Stream Deck for Visual Studio Code

## Features

- Execute any Visual Studio Code command or menu.
- Create and execute terminal commands.
- Insert snippets.

## Building from source

The plugin targets **.NET 8** and builds native binaries for Windows (`win-x64`)
and Apple Silicon macOS (`osx-arm64`). Packaging is done with a cross-platform
bash script that uses Elgato's official CLI — no Windows tooling required.

Requirements:

- [.NET SDK](https://dotnet.microsoft.com/download) 8.0 or newer (the 10.x SDK
  builds the net8.0 target fine).
- [Node.js](https://nodejs.org/) / `npx` (for `@elgato/cli`).
- On macOS: the standard command line tools (`codesign`, `lipo`, `file`).

Build both platform artifacts:

```bash
./build.sh
```

This produces two `.streamDeckPlugin` files in `dist/`:

- `com.nicollasr.streamdeckvsc.streamDeckPlugin` — Windows (`win-x64`)
- `com.nicollasr.streamdeckvsc.mac.streamDeckPlugin` — macOS (`osx-arm64`,
  native Apple Silicon)

To also fold an Intel (`osx-x64`) slice into the macOS executable as a universal
binary, run `BUILD_UNIVERSAL=1 ./build.sh` (note: only the host executable is
made universal; the bundled self-contained .NET runtime remains arm64-only, so
the default arm64 build is recommended for distribution).

## Getting Started

1. Download _Visual Studio Code_ plugin on Stream Deck Store or [here](https://github.com/nicollasricas/vscode-streamdeck/releases/latest).
2. Download _Stream Deck for Visual Studio Code_ on [Visual Studio Code marketplace](https://marketplace.visualstudio.com/items?itemName=nicollasr.vscode-streamdeck) or [here](https://github.com/nicollasricas/vscode-streamdeck/releases/latest).

After installing the plugin and the extension you should see this in VSCode status bar:

![Connected to Stream Deck](https://user-images.githubusercontent.com/7860985/75925951-f97eaa80-5e3f-11ea-8ae2-0a1e7b838380.png)

**If for some reason the focused instance, were not active click on the status bar or alternate between windows to force activation.**

**Only the active session will receive the commands.**

## Getting Commands ID

In Visual Studio Code open _File->Preferences->Keyboard Shortcuts_, find the command you want, right-click it and _Copy Command Id_.

## Settings (Optional)

You can change the IP and port to the message server in the _settings.ini_ file.

    [general]
    host=127.0.0.1
    port=48969

#### Windows

_%appdata%\Elgato\StreamDeck\Plugins\com.nicollasr.streamdeckvsc.sdPlugin\settings.ini_

#### Mac

_~/Library/Application Support/com.elgato.StreamDeck/Plugins/com.nicollasr.streamdeckvsc.mac.sdPlugin/settings.ini_

**Don't forget to change it in Visual Studio Code settings or you won't be able to connect and use the available features.**

_I recommend using 127.0.0.1 as your IP address instead of localhost_.
