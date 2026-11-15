# Claude Assist

A lightweight macOS menu bar app that shows how much of your **Claude** usage limit you have left — at a glance, without opening a terminal.

Claude Assist reads your current usage from the locally installed [Claude Code](https://claude.com/claude-code) CLI and displays it as a small colour-coded bar in the menu bar.

## Features

- **Menu bar meter** – a compact bar showing remaining session usage, colour-coded as usage climbs:
  green → yellow (70% used) → orange (80%) → red (90%).
- **Usage popover** – click the icon to see:
  - Current 5-hour **session** usage and when it resets
  - Current **weekly** usage and when it resets
  - A chart of session usage over the last 6 hours
- **Reset notifications** – get a macOS notification when your session or weekly limit renews.
- **Configurable refresh** – poll every 15 seconds up to 5 minutes.
- **Optional percentage label** next to the menu bar icon.
- **Launch at login** support.
- Right-click (or Control-click) the icon for **Refresh**, **Settings…** and **Quit**.

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://claude.com/claude-code) installed and signed in. The app looks for the `claude` binary in:
  - `~/.local/bin/claude`
  - `~/.claude/local/claude`
  - `/opt/homebrew/bin/claude`
  - `/usr/local/bin/claude`
- Swift 5.9+ toolchain (Xcode or Command Line Tools) to build from source

## How it works

Claude Assist periodically runs:

```sh
claude -p /usage --no-session-persistence
```

The `/usage` command is answered locally by the CLI (no model call, no tokens consumed). The app parses the
`Current session` and `Current week` lines, works out the reset times, and updates the menu bar. The command
runs from a temporary directory so no project settings or hooks are triggered. No data leaves your Mac
beyond what the Claude CLI itself does.

## Build & install

```sh
git clone https://github.com/SarathVavachan/Claude-Assist.git
cd Claude-Assist

# Build the app bundle into ./build/Claude Assist.app
./build.sh

# (Optional) Package a drag-to-install disk image: ./Claude Assist.dmg
./make_dmg.sh
```

Then drag **Claude Assist.app** into `/Applications` (or open the DMG and drag it onto the Applications shortcut).

> The app is ad-hoc signed, so the first time you open it macOS may block it. Right-click the app and choose
> **Open**, or allow it under **System Settings → Privacy & Security**.

To run directly during development:

```sh
swift run
```

## Project structure

```
.
├── Package.swift                 # Swift Package manifest (macOS 13+, executable target)
├── build.sh                      # Builds and ad-hoc signs "Claude Assist.app"
├── make_dmg.sh                   # Packages the app into a DMG
├── Icon/
│   ├── make_icon.swift           # Renders the app icon
│   ├── make_icon.sh              # Converts it into AppIcon.icns
│   ├── AppIcon.png
│   └── AppIcon.icns
└── Sources/ClaudeAssist/
    ├── ClaudeAssistApp.swift     # App entry point and menu bar icon drawing
    ├── StatusBarController.swift # Menu bar item, popover and context menu
    ├── UsagePopoverView.swift    # SwiftUI popover: usage cards and history chart
    ├── UsageService.swift        # Runs the Claude CLI and parses /usage output
    ├── UsageStore.swift          # Polling, caching and usage history
    ├── Notifier.swift            # Reset detection and macOS notifications
    ├── SettingsView.swift        # Settings window and launch-at-login
    └── Preferences.swift         # UserDefaults keys and defaults
```

## Settings

| Setting | Default |
| --- | --- |
| Refresh interval | 30 seconds |
| Show remaining % next to menu bar icon | Off |
| Notify when limits reset | On |
| Launch at login | Off |

## Troubleshooting

- **"Claude CLI not found"** – install Claude Code and make sure `claude` is in one of the paths listed above.
- **Red outlined bar** – the last fetch failed; open the popover to see the error.
- **"Rate limiting requests"** – increase the refresh interval in Settings.
- **No notifications** – allow notifications for Claude Assist in **System Settings → Notifications**, then use
  *Send test notification* in Settings.

## Disclaimer

Claude Assist is an independent, unofficial project and is not affiliated with or endorsed by Anthropic.
