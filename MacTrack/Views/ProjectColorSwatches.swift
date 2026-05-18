import SwiftUI

struct ProjectColorSwatches: View {
    @Binding var selection: String
    var onChange: () -> Void

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(ProjectColors.palette, id: \.self) { hex in
                Button {
                    selection = hex
                    onChange()
                } label: {
                    Circle()
                        .fill(ProjectColors.color(from: hex))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 1)
                            }
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(selection == hex ? Color.primary : Color.clear, lineWidth: 2)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: hex))
            }
        }
    }

    private func accessibilityLabel(for hex: String) -> String {
        selection == hex ? "Selected color" : "Color \(hex)"
    }
}
