import SwiftUI

struct FormatFilterBar: View {
    @Binding var selectedFormat: BookFormat?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(label: "All", icon: "square.grid.2x2", isSelected: selectedFormat == nil) {
                    selectedFormat = nil
                }

                ForEach(BookFormat.allCases) { format in
                    FilterPill(
                        label: format.rawValue,
                        icon: format.icon,
                        isSelected: selectedFormat == format
                    ) {
                        selectedFormat = format
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.quaternary))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
