import Foundation

/// A minimal recursive-descent evaluator for +, -, *, /, and parentheses.
private struct ExpressionParser {
    private let characters: [Character]
    private var position = 0

    init(_ text: String) {
        self.characters = Array(text)
    }

    static func evaluate(_ text: String) -> Double? {
        var parser = ExpressionParser(text)
        guard let value = parser.parseExpression() else { return nil }
        parser.skipWhitespace()
        guard parser.position == parser.characters.count else { return nil }
        return value
    }

    private mutating func parseExpression() -> Double? {
        guard var value = parseTerm() else { return nil }
        while true {
            skipWhitespace()
            guard let op = peek(), op == "+" || op == "-" else { break }
            position += 1
            guard let rhs = parseTerm() else { return nil }
            value = op == "+" ? value + rhs : value - rhs
        }
        return value
    }

    private mutating func parseTerm() -> Double? {
        guard var value = parseFactor() else { return nil }
        while true {
            skipWhitespace()
            guard let op = peek(), op == "*" || op == "/" else { break }
            position += 1
            guard let rhs = parseFactor() else { return nil }
            if op == "/" {
                guard rhs != 0 else { return nil }
                value /= rhs
            } else {
                value *= rhs
            }
        }
        return value
    }

    private mutating func parseFactor() -> Double? {
        skipWhitespace()
        guard let ch = peek() else { return nil }
        if ch == "(" {
            position += 1
            guard let value = parseExpression() else { return nil }
            skipWhitespace()
            guard peek() == ")" else { return nil }
            position += 1
            return value
        }
        if ch == "-" {
            position += 1
            guard let value = parseFactor() else { return nil }
            return -value
        }
        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        skipWhitespace()
        let start = position
        while let ch = peek(), ch.isNumber || ch == "." {
            position += 1
        }
        guard position > start else { return nil }
        return Double(String(characters[start..<position]))
    }

    private func peek() -> Character? {
        position < characters.count ? characters[position] : nil
    }

    private mutating func skipWhitespace() {
        while let ch = peek(), ch == " " {
            position += 1
        }
    }
}

final class CalculatorProvider: ResultProvider {
    let id = "calculator"

    func results(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        guard let firstChar = trimmed.first, firstChar.isNumber || firstChar == "(" || firstChar == "-" else {
            return []
        }
        guard let value = ExpressionParser.evaluate(trimmed) else { return [] }

        let formatted: String
        if value == value.rounded() && abs(value) < 1e15 {
            formatted = String(Int(value))
        } else {
            formatted = String(format: "%.6g", value)
        }

        return [
            SearchResult(
                id: "calc:\(trimmed)",
                title: formatted,
                subtitle: trimmed,
                icon: .system(symbolName: "equal.circle"),
                score: 1.0,
                action: .copyToClipboard(formatted)
            )
        ]
    }
}
