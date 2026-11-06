import Foundation
import OSLog

/// Keeps the reader's ratings on the device and, once they agree to share, sends them to the developers' public
/// CloudKit database. A rating that can't be sent yet is sent on a later try.
actor RatingRepo {
    private struct Stored: Codable {
        /// Names this install's records without saying who the reader is.
        var installID = UUID()
        /// nil until the reader answers.
        var sharesRatings: Bool?
        var ratings: [String: UnderlineRating] = [:]
        var unsent: Set<String> = []
    }

    private static let recordType = "UnderlineRating"
    private let fileURL: URL
    private let cloudSvc: (any CloudSvc)?
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "ratings")
    private var stored: Stored
    private var isSending = false
    #if DEBUG
    private(set) var lastSendResult: String?
    #endif

    init(folder: URL = .applicationSupportDirectory, cloudSvc: (any CloudSvc)? = nil) {
        fileURL = folder.appending(path: "ratings.json")
        self.cloudSvc = cloudSvc
        stored = (try? JSONDecoder().decode(Stored.self, from: Data(contentsOf: fileURL))) ?? Stored()
    }

    var sharesRatings: Bool? {
        stored.sharesRatings
    }

    var unsentCount: Int {
        stored.unsent.count
    }

    func verdict(onUnderline underlineID: String, of book: String) -> Verdict? {
        stored.ratings[Self.key(underlineID, of: book)]?.verdict
    }

    /// No drops what's waiting; yes sends it.
    func setSharesRatings(_ shares: Bool) async {
        stored.sharesRatings = shares
        if !shares { stored.unsent = [] }
        write()
        await sendUnsent()
    }

    func save(_ rating: UnderlineRating) async {
        let key = Self.key(rating.underlineID, of: rating.book)
        stored.ratings[key] = rating
        if stored.sharesRatings != false { stored.unsent.insert(key) }
        write()
        await sendUnsent()
    }

    /// One send at a time. Ratings changed during a send are picked up by the same loop.
    func sendUnsent() async {
        guard let cloudSvc, stored.sharesRatings == true, !isSending else { return }
        isSending = true
        defer {
            isSending = false
            write()
        }
        while let key = stored.unsent.first {
            guard let rating = stored.ratings[key] else {
                stored.unsent.remove(key)
                continue
            }
            let name = "\(stored.installID.uuidString)-\(key)"
            do {
                if let verdict = rating.verdict {
                    try await cloudSvc.save(Self.fields(of: rating, verdict: verdict), asRecord: name, ofType: Self.recordType,
                                            in: .developers)
                } else {
                    try await cloudSvc.deleteRecord(named: name, in: .developers)
                }
                if stored.ratings[key] == rating { stored.unsent.remove(key) }
                #if DEBUG
                lastSendResult = "Sent to Development at \(Date.now.formatted(date: .omitted, time: .standard))"
                #endif
            } catch {
                logger.info("Couldn't send a rating, will try later: \(error.localizedDescription, privacy: .public)")
                #if DEBUG
                lastSendResult = "Couldn't send: \(error.localizedDescription)"
                #endif
                return
            }
        }
    }

    private func write() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Couldn't save ratings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Also part of the record name, so it keeps to letters, digits, "-" and "_".
    private static func key(_ underlineID: String, of book: String) -> String {
        "\(book)-\(underlineID.replacing(":", with: "_"))"
    }

    private static func fields(of rating: UnderlineRating, verdict: Verdict) -> [String: CloudValue] {
        [
            "verdict": .text(verdict.rawValue),
            "book": .text(rating.book),
            "bookTitle": .text(rating.bookTitle),
            "chapterIndex": .number(rating.chapterIndex),
            "phrase": .text(rating.phrase),
            "kind": .text(rating.kind),
            "sentence": .number(rating.sentence),
            "sentenceText": .text(rating.sentenceText),
            "reference": .number(rating.reference),
            "referenceText": .text(rating.referenceText),
            "decidedBy": .text(rating.decidedBy),
            "engineVersion": .number(rating.engineVersion),
            "appVersion": .text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        ]
    }
}
