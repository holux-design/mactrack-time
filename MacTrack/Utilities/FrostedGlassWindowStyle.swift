import AppKit
import SwiftUI

struct FrostedGlassWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> FrostedGlassConfigView {
        FrostedGlassConfigView()
    }

    func updateNSView(_ nsView: FrostedGlassConfigView, context: Context) {}
}

final class FrostedGlassConfigView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
    }
}

private enum FrostedGlassAppearance {
    /// Lighter than `.regularMaterial` — softer blur.
    static let material: Material = .thin
    /// Tints over the material so less desktop shows through.
    static let veilOpacity: Double = 0.38
}

private struct FrostedGlassWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .window) {
                Rectangle()
                    .fill(FrostedGlassAppearance.material)
                    .overlay {
                        Rectangle()
                            .fill(.background.opacity(FrostedGlassAppearance.veilOpacity))
                    }
            }
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .background(FrostedGlassWindowConfigurator())
    }
}

private struct FrostedGlassContentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}

extension View {
    func frostedGlassWindow() -> some View {
        modifier(FrostedGlassWindowModifier())
    }

    func frostedGlassContent() -> some View {
        modifier(FrostedGlassContentModifier())
    }
}
