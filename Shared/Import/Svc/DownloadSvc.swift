import Foundation

/// Downloads an EPUB to a temporary file. A protocol so tests stay offline.
protocol DownloadSvc: Sendable {
    /// Throws `ImportError.tooLarge` over `maxBytes`, `ImportError.unreachable` for any other failure.
    func download(_ url: URL, maxBytes: Int) async throws -> URL
}

struct DownloadSvcURLSession: DownloadSvc {
    func download(_ url: URL, maxBytes: Int) async throws -> URL {
        guard let (file, response) = try? await URLSession.shared.download(for: URLRequest(url: url, timeoutInterval: 30)),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImportError.unreachable
        }
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard http.expectedContentLength <= maxBytes, size <= maxBytes else {
            try? FileManager.default.removeItem(at: file)
            throw ImportError.tooLarge
        }
        let target = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).epub")
        do {
            try FileManager.default.moveItem(at: file, to: target)
        } catch {
            throw ImportError.unreachable
        }
        return target
    }
}
