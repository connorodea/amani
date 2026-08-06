import Foundation

@MainActor
final class SearchController: ObservableObject {
    @Published private(set) var results: [SearchResult] = []
    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }

    private let providers: [ResultProvider]
    private let debounceMilliseconds: Int
    private let providerTimeoutMilliseconds: Int
    private var debounceWorkItem: DispatchWorkItem?
    private var searchGeneration = 0

    init(providers: [ResultProvider], debounceMilliseconds: Int = 120, providerTimeoutMilliseconds: Int = 200) {
        self.providers = providers
        self.debounceMilliseconds = debounceMilliseconds
        self.providerTimeoutMilliseconds = providerTimeoutMilliseconds
    }

    private func scheduleSearch() {
        debounceWorkItem?.cancel()
        let currentQuery = query
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(currentQuery)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(debounceMilliseconds), execute: workItem)
    }

    /// `onComplete` exists so tests can await completion deterministically; production callers
    /// (the didSet-driven path above) can ignore it — results are observed via `@Published`.
    func performSearch(_ query: String, onComplete: (() -> Void)? = nil) {
        searchGeneration += 1
        let generation = searchGeneration

        guard !query.isEmpty else {
            results = []
            onComplete?()
            return
        }

        guard !providers.isEmpty else {
            results = []
            onComplete?()
            return
        }

        let resultsLock = NSLock()
        var combined: [SearchResult] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            // Guards against the race where a provider's work finishes at (almost) the same
            // instant its timeout fires: without this, both the completion block and the
            // timeout block could observe "not yet finished" and each call group.leave(),
            // which is a fatal over-release of the DispatchGroup.
            let finishState = FinishGate()

            DispatchQueue.global(qos: .userInitiated).async {
                let providerResults = provider.results(for: query)
                if finishState.tryFinish() {
                    resultsLock.lock()
                    combined.append(contentsOf: providerResults)
                    resultsLock.unlock()
                    group.leave()
                }
            }

            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .milliseconds(providerTimeoutMilliseconds)
            ) {
                if finishState.tryFinish() {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self, generation == self.searchGeneration else {
                onComplete?()
                return
            }
            self.results = combined.sorted { $0.score > $1.score }
            onComplete?()
        }
    }
}

/// Thread-safe single-shot latch: only the first caller of `tryFinish()` gets `true`.
/// Used to ensure exactly one of {provider completion, timeout} ever calls `group.leave()`
/// for a given provider, regardless of which races to completion first.
private final class FinishGate {
    private let lock = NSLock()
    private var didFinish = false

    func tryFinish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if didFinish { return false }
        didFinish = true
        return true
    }
}
