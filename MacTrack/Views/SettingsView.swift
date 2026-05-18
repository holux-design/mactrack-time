import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Delay") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.debounceMinutes, in: 0...10, step: 0.5)
                        Text(debounceLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
                Text("Waits this long after switching apps before starting a new time block. Set to 0 to switch immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("App switching")
            }

            Section {
                Picker("Snap to", selection: $settings.timelineSnap) {
                    ForEach(TimelineSnapInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                Text("Snaps timeline selections to the nearest time marker when dragging.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Timeline")
            }

            Section {
                Toggle("Launch \(AppIdentity.displayName) at login", isOn: $settings.launchAtLogin)
                Text("Opens \(AppIdentity.displayName) automatically when you sign in to your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Startup")
            }
        }
        .frostedGlassContent()
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Settings")
    }

    private var debounceLabel: String {
        let minutes = settings.debounceMinutes
        if minutes == 0 { return "Off" }
        if minutes == 1 { return "1 min" }
        if minutes.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(minutes)) min"
        }
        return String(format: "%.1f min", minutes)
    }
}
