import Foundation

@main
struct SGAppStorageTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        defer { try? fm.removeItem(at: root) }

        let shared = root.appendingPathComponent("shared", isDirectory: true)
        let privateRoot = root.appendingPathComponent("private", isDirectory: true)
        let group = "group.ph.nigga.graph"
        let normal = try SGAppStorage.resolve(appGroupIdentifier: group, groupContainer: { identifier in
            precondition(identifier == group)
            return shared
        }, privateContainer: privateRoot)
        precondition(normal == shared, "A valid App Group must keep the existing database path")
        precondition(!fm.fileExists(atPath: privateRoot.path), "Shared installs must not create a parallel database")

        let standalone = try SGAppStorage.resolve(appGroupIdentifier: group, groupContainer: { _ in nil }, privateContainer: privateRoot)
        precondition(standalone == privateRoot.appendingPathComponent("NiggagramData", isDirectory: true))
        var isDirectory: ObjCBool = false
        precondition(fm.fileExists(atPath: standalone.path, isDirectory: &isDirectory) && isDirectory.boolValue)
        let sentinel = standalone.appendingPathComponent("existing-data")
        try Data([1, 2, 3]).write(to: sentinel)
        let repeated = try SGAppStorage.resolve(appGroupIdentifier: group, groupContainer: { _ in nil }, privateContainer: privateRoot)
        precondition(repeated == standalone && (try? Data(contentsOf: sentinel)) == Data([1, 2, 3]), "Restart must preserve data")

        let blocker = root.appendingPathComponent("file-not-directory")
        try Data([0]).write(to: blocker)
        var reportedError = false
        do {
            _ = try SGAppStorage.resolve(appGroupIdentifier: group, groupContainer: { _ in nil }, privateContainer: blocker)
        } catch {
            reportedError = true
        }
        precondition(reportedError, "Storage errors must be reported, not silently ignored")
        print("PASS: shared container, no entitlement, directory creation, restart/data preservation, explicit storage error")
    }
}
