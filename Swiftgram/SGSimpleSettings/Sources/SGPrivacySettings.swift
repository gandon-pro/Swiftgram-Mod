import Foundation

public enum SGPrivateActivity {
    case typing, recording, uploading, interaction, call
}

public enum SGPrivacySettings {
    public static let changed = Notification.Name("Swiftgram.LocalPrivacySettingsChanged")
    public static let messageSent = Notification.Name("Niggagram.MessageSent")
    public static var selectedAppIconName: String? {
        get {
            let value = UserDefaults.standard.string(forKey: "sg.mod.selectedAppIconName") ?? ""
            return value.isEmpty ? nil : value
        }
        set { UserDefaults.standard.set(newValue ?? "", forKey: "sg.mod.selectedAppIconName") }
    }
    public static func currentAppIconName(reportedName: String?) -> String? {
        if UserDefaults.standard.object(forKey: "sg.mod.selectedAppIconName") != nil {
            return selectedAppIconName
        }
        return reportedName
    }

    public static var voiceEffect: SGVoiceEffect {
        get { SGVoiceEffect(rawValue: UserDefaults.standard.string(forKey: "sg.mod.voiceEffect") ?? "") ?? .off }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "sg.mod.voiceEffect")
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    public static var swiftpseudoPro: Bool {
        get { preference("sg.mod.swiftpseudoPro", defaultValue: false) }
        set { set(newValue, for: "sg.mod.swiftpseudoPro") }
    }

    /// Local client features only. Never changes the stored purchase status,
    /// StoreKit receipts or the server subscription associated with an account.
    public static func allowsLocalPro(status: Int64) -> Bool {
        return swiftpseudoPro || status > 1
    }

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
    public static var ghostHideOnlineAfterSend: Bool {
        get { preference("sg.mod.hideOnlineAfterSend") }
        set { set(newValue, for: "sg.mod.hideOnlineAfterSend") }
    }
    public static var hideOnlineAfterSend: Bool { ghostMode && ghostHideOnlineAfterSend }
    public static var pastavibeEmojiStatusFileId: Int64? {
        get { (UserDefaults.standard.object(forKey: "sg.mod.pastavibeEmojiStatusFileId") as? NSNumber)?.int64Value }
        set {
            if let value = newValue { UserDefaults.standard.set(NSNumber(value: value), forKey: "sg.mod.pastavibeEmojiStatusFileId") }
            else { UserDefaults.standard.removeObject(forKey: "sg.mod.pastavibeEmojiStatusFileId") }
        }
    }

    public static var copyProtectedMessages: Bool {
        get { preference("sg.mod.copyProtectedMessages", defaultValue: false) }
        set { set(newValue, for: "sg.mod.copyProtectedMessages") }
    }

    public static var unlimitedDeletedMessagesArchive: Bool {
        get { preference("sg.mod.unlimitedDeletedMessagesArchive", defaultValue: false) }
        set { set(newValue, for: "sg.mod.unlimitedDeletedMessagesArchive") }
    }

    /// A nil limit means retention never evicts entries by count.
    public static var effectiveDeletedMessagesLimit: Int? {
        return unlimitedDeletedMessagesArchive ? nil : deletedMessagesLimit
    }

    public static func deletedArchiveOverflow(count: Int) -> Int {
        guard let limit = effectiveDeletedMessagesLimit else { return 0 }
        return max(0, count - limit)
    }

    public static var deletedMessagesLimit: Int {
        get {
            guard let value = UserDefaults.standard.object(forKey: "sg.mod.deletedMessagesLimit") as? Int else { return 200 }
            return min(10000, max(1, value))
        }
        set {
            UserDefaults.standard.set(min(10000, max(1, newValue)), forKey: "sg.mod.deletedMessagesLimit")
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }
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
    public static func shouldRetainMessage(isTimedMedia: Bool, hasExpiringMedia: Bool) -> Bool {
        return keepDeletedMessages && (isTimedMedia || !hasExpiringMedia)
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
