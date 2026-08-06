import SwiftUI

struct SearchView: View {
    @ObservedObject var searchController: SearchController
    let onSubmit: (SearchResult) -> Void

    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                OrbView(state: searchController.query.isEmpty ? .idle : .active)
                    .frame(width: 28, height: 28)
                TextField("Search apps, files, or type a sum…", text: $searchController.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
            }
            .padding(16)

            if !searchController.results.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(searchController.results.enumerated()), id: \.element.id) { index, result in
                            ResultRowView(result: result, isSelected: index == selectedIndex)
                                .onTapGesture { onSubmit(result) }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 640)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: searchController.results.count) { _, _ in selectedIndex = 0 }
    }
}
