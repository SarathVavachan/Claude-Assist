import AppKit
import SwiftUI
import Combine

/// Owns the menu bar item: left click toggles the usage popover,
/// right click (or control-click) shows the context menu.
@MainActor
final class StatusBarController: NSObject {
    private let store: UsageStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        super.init()

        let hosting = NSHostingController(rootView: UsagePopoverView(store: store, onOpenSettings: { [weak self] in
            self?.popover.performClose(nil)
            self?.openSettings()
        }))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeft
        }

        // @Published emits before the property is set, so use the emitted values.
        store.$snapshot.combineLatest(store.$errorMessage)
            .sink { [weak self] snapshot, error in self?.updateButton(snapshot: snapshot, error: error) }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.showPercentInMenuBar)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateButton(snapshot: self.store.snapshot, error: self.store.errorMessage)
            }
            .store(in: &cancellables)
    }

    private func updateButton(snapshot: UsageSnapshot?, error: String?) {
        guard let button = statusItem.button else { return }
        let remaining = snapshot?.session.remaining
        button.image = MenuBarIcon.image(remaining: remaining, hasError: error != nil && snapshot == nil)
        if UserDefaults.standard.showPercentInMenuBar, let remaining {
            button.title = " \(Int(remaining.rounded()))%"
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            button.title = ""
        }
    }

    // MARK: - Clicks

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu() {
        popover.performClose(nil)
        // Temporarily attach the menu so AppKit positions and highlights it like a native item.
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.font = .menuFont(ofSize: 12)

        if let note = store.statusNote(now: Date()) {
            menu.addItem(infoItem(note, symbol: "exclamationmark.triangle"))
            menu.addItem(.separator())
        }

        menu.addItem(actionItem("Refresh", #selector(refresh), key: "r", symbol: "arrow.clockwise"))
        menu.addItem(actionItem("Settings…", #selector(openSettings), key: ",", symbol: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit", #selector(quit), key: "q", symbol: "power"))
        return menu
    }

    private func infoItem(_ title: String, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = paddedTitle(title, color: .secondaryLabelColor)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, key: String, symbol: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.attributedTitle = paddedTitle(title)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.target = self
        return item
    }

    /// NSMenu has no padding setting, so make rows taller with a fixed line
    /// height and lift the baseline to keep the text vertically centered.
    private func paddedTitle(_ title: String, color: NSColor? = nil) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 12)
        let rowHeight: CGFloat = 24
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = rowHeight
        paragraph.maximumLineHeight = rowHeight
        let naturalHeight = font.ascender - font.descender + font.leading
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .baselineOffset: (rowHeight - naturalHeight) / 2,
        ]
        if let color { attributes[.foregroundColor] = color }
        return NSAttributedString(string: title, attributes: attributes)
    }

    // MARK: - Actions

    @objc private func refresh() {
        store.refresh()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Claude Assist Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
