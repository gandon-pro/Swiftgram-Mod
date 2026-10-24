import Foundation

@main struct SGModBuildInfoTests {
    static func main() {
        precondition(SGModBuildInfo.text(info: [:]) == "v— · #local")
        precondition(SGModBuildInfo.text(info: ["CFBundleShortVersionString": "12.1", "CFBundleVersion": "24"]) == "v12.1 · #24")
        let info: [String: Any] = ["CFBundleShortVersionString": "12.1", "CFBundleVersion": "1", "SGModBuildNumber": "42", "SGModCommit": "abcdef0123456789"]
        precondition(SGModBuildInfo.text(info: info) == "v12.1 · #42 · abcdef01", "CI build number survives a re-signer changing CFBundleVersion")
        precondition(SGModBuildInfo.text(info: ["SGModBuildNumber": "", "CFBundleVersion": "25"]) == "v— · #25")
        print("PASS: build footer metadata, commit and re-signing fallback")
    }
}
