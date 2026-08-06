import SwiftUI

/// Golden-ratio-derived spacing/type scale, per the design philosophy in VISION.md — a single
/// base unit scaled by φ (1.618) rather than picking pixel values by feel.
private enum Layout {
    static let phi: CGFloat = 1.618
    static let unit: CGFloat = 12

    static let spacingTight = unit                // ~12 — gap between orb and text field
    static let spacingCozy = (unit * phi).rounded()      // ~19 — outer padding around the search row
    static let spacingLoose = (unit * phi * phi).rounded() // ~31 — padding around the results list

    static let cornerRadius = (unit * phi).rounded()      // ~19
    static let orbSize = (unit * phi * 1.5).rounded()     // ~29, visually close to the text baseline
    static let fontSize = (unit * phi).rounded()          // ~19
    static let panelWidth: CGFloat = 640
    static let resultsMaxHeight: CGFloat = 360
}

struct SearchView: View {
    @ObservedObject var searchController: SearchController
    let onSubmit: (SearchResult) -> Void

    @State private var selectedIndex = 0
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Layout.spacingTight) {
                OrbView(state: searchController.query.isEmpty ? .idle : .active)
                    .frame(width: Layout.orbSize, height: Layout.orbSize)
                TextField("Search apps, files, or type a sum…", text: $searchController.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: Layout.fontSize))
                    .focused($searchFieldFocused)
            }
            .padding(Layout.spacingCozy)

            if !searchController.results.isEmpty {
                Divider()
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(searchController.results.enumerated()), id: \.element.id) { index, result in
                                ResultRowView(result: result, isSelected: index == selectedIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = index
                                        onSubmit(result)
                                    }
                            }
                        }
                        .padding(Layout.spacingTight)
                    }
                    .frame(maxHeight: Layout.resultsMaxHeight)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.12)) {
                            scrollProxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }

                Divider()
                HStack(spacing: Layout.spacingTight) {
                    Spacer()
                    Label("navigate", systemImage: "arrow.up.arrow.down")
                    Label("select", systemImage: "return")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Layout.spacingCozy)
                .padding(.vertical, 6)
            }
        }
        .frame(width: Layout.panelWidth)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
        )
        .onChange(of: searchController.results.count) { _, _ in selectedIndex = 0 }
        .onKeyPress(.downArrow) {
            guard !searchController.results.isEmpty else { return .ignored }
            selectedIndex = min(selectedIndex + 1, searchController.results.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !searchController.results.isEmpty else { return .ignored }
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            guard searchController.results.indices.contains(selectedIndex) else { return .ignored }
            onSubmit(searchController.results[selectedIndex])
            return .handled
        }
        .onAppear { searchFieldFocused = true }
    }
}
