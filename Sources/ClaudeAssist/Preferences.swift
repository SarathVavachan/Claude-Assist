import Foundation

/// UserDefaults-backed settings. Properties are `@objc dynamic` so they can be
/// observed with KVO; their names must match the defaults keys.
extension UserDefaults {
    enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showPercentInMenuBar = "showPercentInMenuBar"
        static let notifyOnReset = "notifyOnReset"
    }

    static func registerAppDefaults() {
        standard.register(defaults: [
            Keys.refreshInterval: 30,
            Keys.showPercentInMenuBar: false,
            Keys.notifyOnReset: true,
        ])
    }

    @objc dynamic var refreshInterval: Int { integer(forKey: Keys.refreshInterval) }
    @objc dynamic var showPercentInMenuBar: Bool { bool(forKey: Keys.showPercentInMenuBar) }
}
