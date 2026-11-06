import Testing
@testable import iRead

@Suite("BookFingerprint")
struct BookFingerprintTests {
    @Test("BK-16 the same text gives the same fingerprint; other text, or other chapter breaks, give another")
    func fingerprint() {
        let chapters = [["Anna opened the box."], ["The key turned."]]
        let fingerprint = BookContent.make(chapters: chapters).fingerprint
        #expect(BookContent.make(chapters: chapters).fingerprint == fingerprint)
        #expect(BookContent.make(chapters: [["Anna opened the box!"], ["The key turned."]]).fingerprint != fingerprint)
        #expect(BookContent.make(chapters: [["Anna opened the box.", "The key turned."]]).fingerprint != fingerprint)
    }
}
