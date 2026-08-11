import Foundation

enum FuzzyMatch {
    /// Returns a score in (0, 1] if `target` matches `query`, or nil if it doesn't match at all.
    /// Exact prefix > substring > ordered-subsequence, so "saf" ranks "Safari" above a looser match.
    static func score(query: String, target: String) -> Double? {
        guard !query.isEmpty else { return nil }
        let q = query.lowercased()
        let t = target.lowercased()

        if t.hasPrefix(q) { return 1.0 }
        if t.contains(q) { return 0.75 }

        var qi = q.startIndex
        var matched = 0
        for ch in t {
            if qi < q.endIndex, ch == q[qi] {
                matched += 1
                qi = q.index(after: qi)
            }
        }
        guard qi == q.endIndex, matched > 0 else { return nil }
        return 0.4 * Double(matched) / Double(t.count)
    }
}
