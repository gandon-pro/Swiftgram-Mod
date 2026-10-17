import Foundation

public enum SGPrivateActivity {
    case typing, recording, uploading, interaction, call
}

public enum SGPrivacySettings {
    public static let changed = Notification.Name("Swiftgram.LocalPrivacySettingsChanged")

    private static func preference(_ key: String, defaultValue: Bool = true) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
    private static func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
    public static var ghostMode: Bool {
        get {
            if let enabled = UserDefaults.standard.object(forKey: "sg.mod.ghostEnabled") as? Bool { return enabled }
            let migrated = ["sg.mod.hideOnline", "sg.mod.hideTyping", "sg.mod.hideReadReceipts"].contains { UserDefaults.standard.bool(forKey: $0) }
            UserDefaults.standard.set(migrated, forKey: "sg.mod.ghostEnabled")
            return migrated
        }
        set { set(newValue, for: "sg.mod.ghostEnabled") }
    }
    public static var ghostHideOnline: Bool {
        get { preference("sg.mod.hideOnline") }
        set { set(newValue, for: "sg.mod.hideOnline") }
    }
    public static var ghostHideTyping: Bool {
        get { preference("sg.mod.hideTyping") }
        set { set(newValue, for: "sg.mod.hideTyping") }
    }
    public static var ghostHideReadReceipts: Bool {
        get { preference("sg.mod.hideReadReceipts") }
        set { set(newValue, for: "sg.mod.hideReadReceipts") }
    }
    public static var ghostHideRecording: Bool {
        get { preference("sg.mod.hideRecording") }
        set { set(newValue, for: "sg.mod.hideRecording") }
    }
    public static var ghostHideUploads: Bool {
        get { preference("sg.mod.hideUploads") }
        set { set(newValue, for: "sg.mod.hideUploads") }
    }
    public static var ghostHideStories: Bool {
        get { preference("sg.mod.hideStoryViews") }
        set { set(newValue, for: "sg.mod.hideStoryViews") }
    }
    public static var ghostHideInteractions: Bool {
        get { preference("sg.mod.hideInteractions") }
        set { set(newValue, for: "sg.mod.hideInteractions") }
    }
    public static var hideOnline: Bool { ghostMode && ghostHideOnline }
    public static var hideTyping: Bool { ghostMode && ghostHideTyping }
    public static var hideReadReceipts: Bool { ghostMode && ghostHideReadReceipts }
    public static var hideStoryViews: Bool { ghostMode && ghostHideStories }

    public static func suppressActivity(_ activity: SGPrivateActivity) -> Bool {
        guard ghostMode else { return false }
        switch activity {
        case .typing: return ghostHideTyping
        case .recording: return ghostHideRecording
        case .uploading: return ghostHideUploads
        case .interaction: return ghostHideInteractions
        case .call: return false
        }
    }
    public static var keepDeletedMessages: Bool {
        get { preference("sg.mod.keepDeletedMessages", defaultValue: false) }
        set { set(newValue, for: "sg.mod.keepDeletedMessages") }
    }
    public static var backgroundDeletedMessages: Bool {
        get { preference("sg.mod.backgroundDeletedMessages", defaultValue: false) }
        set { set(newValue, for: "sg.mod.backgroundDeletedMessages") }
    }
    public static var videoNotes60FPS: Bool {
        get { preference("sg.mod.videoNotes60FPS", defaultValue: false) }
        set { set(newValue, for: "sg.mod.videoNotes60FPS") }
    }
}
