import Foundation

enum SearchResultIcon: Equatable {
    case app(bundleURL: URL)
    case file(path: String)
    case system(symbolName: String)
}

enum SearchResultAction: Equatable {
    case launchApp(bundleURL: URL)
    case openFile(path: String)
    case copyToClipboard(String)
}

struct SearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: SearchResultIcon
    let score: Double
    let action: SearchResultAction
}

protocol ResultProvider {
    var id: String { get }
    func results(for query: String) -> [SearchResult]
}
