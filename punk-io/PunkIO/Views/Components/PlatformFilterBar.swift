import SwiftUI

struct PlatformFilterBar: View {
    @Binding var selected: PlatformSource?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    title: "Todos",
                    icon: "sparkles",
                    isSelected: selected == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selected = nil
                    }
                }

                ForEach(PlatformSource.allCases) { platform in
                    FilterChip(
                        title: platform.rawValue,
                        icon: platform.icon,
                        isSelected: selected == platform
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selected = platform
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}
