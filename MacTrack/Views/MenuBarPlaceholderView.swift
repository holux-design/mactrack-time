import SwiftUI

struct MenuBarPlaceholderView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Starting \(AppIdentity.displayName)…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 200, height: 72)
        .padding(12)
        .frostedGlassWindow()
    }
}
