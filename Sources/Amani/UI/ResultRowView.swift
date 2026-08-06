import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                Text(result.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var iconView: some View {
        switch result.icon {
        case .app(let bundleURL):
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                .resizable()
                .frame(width: 28, height: 28)
        case .file:
            Image(systemName: "doc")
                .frame(width: 28, height: 28)
        case .system(let symbolName):
            Image(systemName: symbolName)
                .frame(width: 28, height: 28)
        }
    }
}
