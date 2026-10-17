import Foundation

@main
struct ICloudFileAccessTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for ext in ["apk", "ipa"] {
            let url = directory.appendingPathComponent("test file 100%." + ext)
            let payload = Data([0x50, 0x4b, 3, 4, 0, 255])
            try payload.write(to: url)
            var releases = 0
            var access: ICloudFileAccess? = ICloudFileAccess(url: url, start: { _ in false }, stop: { _ in releases += 1 })
            let received = try Data(contentsOf: access!.url)
            precondition(received == payload, "A local file must work without a security scope")
            access = nil
            precondition(releases == 0, "Do not stop a scope which was never acquired")
            access = ICloudFileAccess(url: url, start: { _ in true }, stop: { _ in releases += 1 })
            let retainedForUpload = access!
            access = nil
            precondition(releases == 0)
            withExtendedLifetime(retainedForUpload) {
                precondition(FileManager.default.isReadableFile(atPath: retainedForUpload.url.path))
            }
        }
        var releases = 0
        var granted: ICloudFileAccess? = ICloudFileAccess(url: directory, start: { _ in true }, stop: { _ in releases += 1 })
        precondition(granted != nil)
        granted = nil
        precondition(releases == 1)
        print("PASS: local APK/IPA without scope, filename preservation, grant ownership during upload and balanced release")
    }
}
