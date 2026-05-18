import SwiftUI

/// Compact previous / date / next control for toolbar day selection.
struct DayNavigationControl: View {
    @Binding var day: Date

    @State private var showsCalendar = false

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "chevron.left", help: "Previous day") {
                shiftDay(by: -1)
            }

            Button {
                showsCalendar = true
            } label: {
                Text(day, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .frame(minWidth: 96, maxHeight: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsCalendar, arrowEdge: .top) {
                VStack(spacing: 10) {
                    DatePicker("", selection: $day, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()

                    HStack {
                        Spacer()
                        Button("Today") {
                            day = calendar.startOfDay(for: .now)
                            showsCalendar = false
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(12)
            }
            .help("Pick a date")

            stepButton(systemName: "chevron.right", help: "Next day") {
                shiftDay(by: 1)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 6)
        .controlSize(.small)
        .onChange(of: day) { _, newValue in
            let normalized = calendar.startOfDay(for: newValue)
            if normalized != newValue {
                day = normalized
            }
        }
    }

    private func stepButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func shiftDay(by offset: Int) {
        let start = calendar.startOfDay(for: day)
        day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
}
