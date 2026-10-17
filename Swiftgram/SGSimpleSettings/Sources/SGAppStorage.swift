import Foundation

/// Re-signed installations may have no App Groups entitlement. In that case
/// the main app must use its own sandbox; extensions cannot share that data.
public enum SGAppStorage {
    public static func resolve(
        appGroupIdentifier: String,
        groupContainer: (String) -> URL?,
        privateContainer: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        if let shared = groupContainer(appGroupIdentifier) {
            return shared
        }
        let standalone = privateContainer.appendingPathComponent("NiggagramData", isDirectory: true)
        try fileManager.createDirectory(at: standalone, withIntermediateDirectories: true, attributes: nil)
        return standalone
    }
}
