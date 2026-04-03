import SwiftUI

struct RealmRowView: View {
    let realm: RealmInfo
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    // Realm name
                    Text(realm.name)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    Spacer()

                    // Player count
                    if realm.state == .open {
                        Text("\(realm.playerCount)")
                            .font(.system(.body, weight: .semibold, design: .rounded))
                            .foregroundStyle(realm.playerCount > 0 ? .primary : .secondary)
                    } else {
                        Text("off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)

            // Online players (expandable)
            if !realm.onlinePlayers.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text(realm.onlinePlayers.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.leading, 34)
                    .padding(.trailing, 16)
                    .padding(.bottom, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statusColor: Color {
        switch realm.state {
        case .open where realm.playerCount > 0: return .green
        case .open: return .green.opacity(0.5)
        case .closed: return .gray
        case .unknown: return .orange
        }
    }
}
