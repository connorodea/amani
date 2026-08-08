import SwiftUI

/// A conventional 4pt-multiple spacing scale — replaced an earlier golden-ratio-derived scale
/// (12 × φⁿ), which produced odd, non-standard values (19, 27, 31...) that stacks-guidance
/// research flagged directly ("Use design system spacing values... Don't: magic numbers for
/// spacing"). Every value below is a multiple of 4, matching how native macOS launcher UIs
/// (and this app's own footer/panel chrome) are actually spaced.
private enum Layout {
    static let spacingTight: CGFloat = 12   // gap between orb and text field
    static let spacingCozy: CGFloat = 20    // outer padding around the search row

    static let cornerRadius: CGFloat = 16
    static let orbSize: CGFloat = 20        // a quiet status indicator, not a mascot
    static let fontSize: CGFloat = 20
    static let panelWidth: CGFloat = 640
    static let resultsMaxHeight: CGFloat = 360
}

/// Keyboard navigation (arrows/return/escape) is driven by an `NSEvent` monitor in
/// `OverlayWindowController`, not `.onKeyPress` here — SwiftUI's `.onKeyPress` was found to
/// intercept ordinary character keystrokes before they reached this view's `TextField`, making
/// the search box untypable. `searchController.selectedIndex` is the single source of truth for
/// which row is highlighted, shared between that monitor and this view.
struct SearchView: View {
    @ObservedObject var searchController: SearchController
    let onSubmit: (SearchResult) -> Void

    @FocusState private var searchFieldFocused: Bool

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Layout.spacingTight) {
                OrbView(state: searchController.query.isEmpty ? .idle : .active)
                    .frame(width: Layout.orbSize, height: Layout.orbSize)
                TextField("Search apps, files, or do the math…", text: $searchController.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: Layout.fontSize, weight: .regular))
                    .focused($searchFieldFocused)
            }
            .padding(.horizontal, Layout.spacingCozy)
            .padding(.vertical, 16)

            if !searchController.results.isEmpty {
                hairline
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(searchController.results.enumerated()), id: \.element.id) { index, result in
                                ResultRowView(result: result, isSelected: index == searchController.selectedIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        searchController.selectedIndex = index
                                        onSubmit(result)
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: Layout.resultsMaxHeight)
                    .onChange(of: searchController.selectedIndex) { _, newValue in
                        // Deferred a tick: scrolling synchronously here can land inside the same
                        // layout pass NSHostingView uses to auto-resize the panel to fit the
                        // results list as they appear, which AppKit warns about as re-entrant
                        // layout ("-layoutSubtreeIfNeeded on a view which is already being laid
                        // out"). Posting to the next run loop turn avoids the overlap.
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.12)) {
                                scrollProxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }

                hairline
                HStack(spacing: 8) {
                    Spacer()
                    KeyBadge(symbol: "arrow.up")
                    KeyBadge(symbol: "arrow.down")
                    Text("navigate")
                        .padding(.trailing, 8)
                    KeyBadge(symbol: "return")
                    Text("select")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Layout.spacingCozy)
                .padding(.vertical, 8)
            }
        }
        .frame(width: Layout.panelWidth)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear { searchFieldFocused = true }
        .onChange(of: searchController.activationTick) { _, _ in searchFieldFocused = true }
    }
}

/// A small monospaced, rounded-rect key-cap — the shorthand keyboard-shortcut badge style used
/// by Vercel/Linear/Raycast, in place of a plain SF Symbol + text label.
private struct KeyBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 18, height: 18)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
