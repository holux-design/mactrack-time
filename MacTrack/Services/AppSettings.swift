import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let debounce = "appSwitchDebounceSeconds"
        static let launchAtLogin = "launchAtLogin"
        static let timelineSnap = "timelineSnapInterval"
    }

    @Published var appSwitchDebounceSeconds: TimeInterval {
        didSet {
            let clamped = max(0, appSwitchDebounceSeconds)
            if clamped != appSwitchDebounceSeconds {
                appSwitchDebounceSeconds = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.debounce)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginHelper.setEnabled(launchAtLogin)
        }
    }

    @Published var timelineSnap: TimelineSnapInterval {
        didSet {
            UserDefaults.standard.set(timelineSnap.rawValue, forKey: Keys.timelineSnap)
        }
    }

    private init() {
        let storedDebounce = UserDefaults.standard.object(forKey: Keys.debounce) as? TimeInterval
        appSwitchDebounceSeconds = storedDebounce ?? 60

        if UserDefaults.standard.object(forKey: Keys.launchAtLogin) != nil {
            launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)
        } else {
            launchAtLogin = LaunchAtLoginHelper.isEnabled
        }

        if let raw = UserDefaults.standard.string(forKey: Keys.timelineSnap),
           let stored = TimelineSnapInterval(rawValue: raw) {
            timelineSnap = stored
        } else {
            timelineSnap = .quarterHour
        }
    }

    var debounceMinutes: Double {
        get { appSwitchDebounceSeconds / 60 }
        set { appSwitchDebounceSeconds = max(0, newValue * 60) }
    }
}
