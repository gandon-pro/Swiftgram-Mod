import Foundation

/// Re-signing a release IPA can select a development APNs profile. DEBUG is
/// therefore only a fallback when no readable embedded profile is available.
/// This reads configuration, not signature trust; iOS validates the signature.
public enum SGPushEnvironment {
    public static let isSandbox: Bool = {
        #if DEBUG
        let fallback = true
        #else
        let fallback = false
        #endif
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return fallback
        }
        return sandbox(profileData: data) ?? fallback
    }()

    public static var tokenEnvironment: String {
        return isSandbox ? "sandbox" : "production"
    }

    public static func sandbox(profileData: Data) -> Bool? {
        // Provisioning profiles contain an XML plist in a CMS envelope.
        guard profileData.count <= 4 * 1024 * 1024,
              let start = profileData.range(of: Data("<?xml".utf8)),
              let end = profileData.range(of: Data("</plist>".utf8), in: start.lowerBound ..< profileData.endIndex),
              let object = try? PropertyListSerialization.propertyList(
                from: profileData.subdata(in: start.lowerBound ..< end.upperBound), options: [], format: nil),
              let profile = object as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any],
              let environment = entitlements["aps-environment"] as? String else {
            return nil
        }
        switch environment {
        case "development": return true
        case "production": return false
        default: return nil
        }
    }
}
