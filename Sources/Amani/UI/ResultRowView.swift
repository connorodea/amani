import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary)
                Text(result.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            // A flat neutral fill on selection, not a colored border — command palettes in the
            // Vercel/Linear/Raycast style reserve accent color for rare, deliberate moments and
            // keep row-selection itself strictly grayscale.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        Group {
            switch result.icon {
            case .app(let bundleURL):
                Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                    .resizable()
            case .file:
                Image(systemName: "doc.text")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            case .system(let symbolName):
                Image(systemName: symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 26, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .opacity(isFileOrSystemIcon ? 1 : 0)
        )
    }

    private var isFileOrSystemIcon: Bool {
        if case .app = result.icon { return false }
        return true
    }
}
