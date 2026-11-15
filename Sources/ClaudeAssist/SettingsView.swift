import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(UserDefaults.Keys.refreshInterval) private var refreshInterval = 30
    @AppStorage(UserDefaults.Keys.showPercentInMenuBar) private var showPercentInMenuBar = false
    @AppStorage(UserDefaults.Keys.notifyOnReset) private var notifyOnReset = true
    @StateObject private var loginItem = LoginItem()

    private let intervals: [(label: String, seconds: Int)] = [
        ("15 seconds", 15), ("30 seconds", 30), ("1 minute", 60), ("2 minutes", 120), ("5 minutes", 300),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ClaudeLogo(color: Color(red: 0.85, green: 0.47, blue: 0.34))
                    .frame(width: 18, height: 18)
                Text("Settings").font(.system(size: 16.9, weight: .bold))
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Refresh every").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Picker("", selection: $refreshInterval) {
                        ForEach(intervals, id: \.seconds) { Text($0.label).tag($0.seconds) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                row("Show remaining % next to menu bar icon", isOn: $showPercentInMenuBar)
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                row("Notify me when limits reset", isOn: $notifyOnReset)
                if notifyOnReset {
                    Button("Send test notification") { Notifier.sendTest() }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                row("Launch at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if let error = loginItem.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
        }
        .padding(16)
        .frame(width: 440)
        .background(Theme.background.ignoresSafeArea())
    }

    private func row(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 24)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(nsColor: .systemGreen))
        }
    }
}

/// Wraps the app's login item registration.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var error: String?

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = "Couldn't update login item: \(error.localizedDescription)"
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
