import Foundation

/// Device-local options. No cached wrapper: the networking queues read the latest value.
public enum SGPrivacySettings {
    public static let changed = Notification.Name("Swiftgram.LocalPrivacySettingsChanged")

    private static func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }

    public static var hideOnline: Bool {
        get { UserDefaults.standard.bool(forKey: "sg.mod.hideOnline") }
        set { set(newValue, for: "sg.mod.hideOnline") }
    }

    public static var hideTyping: Bool {
        get { UserDefaults.standard.bool(forKey: "sg.mod.hideTyping") }
        set { set(newValue, for: "sg.mod.hideTyping") }
    }

    public static var hideReadReceipts: Bool {
        get { UserDefaults.standard.bool(forKey: "sg.mod.hideReadReceipts") }
        set { set(newValue, for: "sg.mod.hideReadReceipts") }
    }

    public static var keepDeletedMessages: Bool {
        get { UserDefaults.standard.bool(forKey: "sg.mod.keepDeletedMessages") }
        set { set(newValue, for: "sg.mod.keepDeletedMessages") }
    }
}
