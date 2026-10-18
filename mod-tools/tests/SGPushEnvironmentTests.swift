import Foundation

@main
struct SGPushEnvironmentTests {
    static func main() throws {
        func profile(_ entitlements: [String: Any]) throws -> Data {
            let xml = try PropertyListSerialization.data(fromPropertyList: ["Entitlements": entitlements], format: .xml, options: 0)
            return Data([0x30, 0x82, 0xff]) + xml + Data([0, 0xff])
        }
        let development = try profile(["aps-environment": "development"])
        let production = try profile(["aps-environment": "production"])
        let missing = try profile([:])
        let invalid = try profile(["aps-environment": "invalid"])
        precondition(SGPushEnvironment.sandbox(profileData: development) == true)
        precondition(SGPushEnvironment.sandbox(profileData: production) == false)
        precondition(SGPushEnvironment.sandbox(profileData: missing) == nil)
        precondition(SGPushEnvironment.sandbox(profileData: invalid) == nil)
        precondition(SGPushEnvironment.sandbox(profileData: Data("<?xml broken </plist>".utf8)) == nil)
        precondition(SGPushEnvironment.sandbox(profileData: Data()) == nil)
        precondition(SGPushEnvironment.sandbox(profileData: Data(repeating: 0, count: 4 * 1024 * 1024 + 1)) == nil)
        print("PASS: development, production, missing capability, unknown environment, malformed and oversized profiles")
    }
}
