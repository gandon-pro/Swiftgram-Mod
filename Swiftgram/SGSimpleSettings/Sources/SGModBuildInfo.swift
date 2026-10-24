import Foundation

public enum SGModBuildInfo {
    public static var text: String { return text(info: Bundle.main.infoDictionary ?? [:]) }

    public static func text(info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = (info["SGModBuildNumber"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (info["CFBundleVersion"] as? String) ?? "local"
        let commit = info["SGModCommit"] as? String ?? ""
        return "v\(version) · #\(build)" + (commit.isEmpty ? "" : " · " + String(commit.prefix(8)))
    }
}
