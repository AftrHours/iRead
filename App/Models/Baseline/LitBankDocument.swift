import Foundation

struct LitBankSpan: Sendable {
    let firstToken: Int
    let lastToken: Int
    let label: String
}

enum LitBankError: Error {
    case tokenCountMismatch(text: Int, entities: Int)
}

struct LitBankDocument: Sendable {
    let tokens: [String]
    let spans: [LitBankSpan]

    init(textURL: URL, entitiesURL: URL) throws {
        tokens = try String(contentsOf: textURL, encoding: .utf8).split(whereSeparator: \.isWhitespace).map(String.init)
        let rows = try String(contentsOf: entitiesURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
            .filter { !$0.isEmpty && !$0[0].allSatisfy(\.isWhitespace) }
        guard rows.count == tokens.count else { throw LitBankError.tokenCountMismatch(text: tokens.count, entities: rows.count) }
        spans = Self.spans(outerTags: rows.map { $0.count > 1 ? String($0[1]) : "O" })
    }

    static func littleWomen(in bundle: Bundle = .main) throws -> LitBankDocument {
        guard let text = bundle.url(forResource: "514_little_women", withExtension: "txt"),
              let entities = bundle.url(forResource: "514_little_women.entities", withExtension: "tsv") else {
            throw ContentError.unreadable
        }
        return try LitBankDocument(textURL: text, entitiesURL: entities)
    }

    private static func spans(outerTags: [String]) -> [LitBankSpan] {
        var spans: [LitBankSpan] = []
        var open: (first: Int, label: String)?
        func close(at last: Int) {
            if let open { spans.append(LitBankSpan(firstToken: open.first, lastToken: last, label: open.label)) }
            open = nil
        }
        for (index, tag) in outerTags.enumerated() {
            let parts = tag.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { close(at: index - 1); continue }
            if parts[0] == "I", open?.label == parts[1] { continue }
            close(at: index - 1)
            open = (index, parts[1])
        }
        close(at: outerTags.count - 1)
        return spans
    }
}
