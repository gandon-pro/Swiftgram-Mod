import Foundation

/// A sandbox-local URL needs no security scope; false is not an access error.
/// External grants are held until the asynchronous resource copy is finished.
final class ICloudFileAccess {
    let url: URL
    private let release: (() -> Void)?

    init(url: URL, start: (URL) -> Bool = { $0.startAccessingSecurityScopedResource() }, stop: @escaping (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }) {
        self.url = url
        self.release = start(url) ? { stop(url) } : nil
    }

    deinit {
        self.release?()
    }
}
