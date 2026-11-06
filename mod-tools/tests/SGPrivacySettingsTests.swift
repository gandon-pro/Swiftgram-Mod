import Foundation

@main
struct SGPrivacySettingsTests {
    static func main() {
        let defaults = UserDefaults.standard
        let keys = ["selectedAppIconName", "swiftpseudoPro", "ghostEnabled", "hideOnline", "hideOnlineAfterSend", "deletedMessagesLimit", "unlimitedDeletedMessages", "pastavibeEmojiStatusFileId", "hideTyping", "hideReadReceipts", "hideRecording", "hideUploads", "hideStoryViews", "hideInteractions", "keepDeletedMessages", "backgroundDeletedMessages", "videoNotes60FPS"].map { "sg.mod." + $0 }
        let old = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, old) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        precondition(SGPrivacySettings.currentAppIconName(reportedName: "SGSky") == "SGSky")
        SGPrivacySettings.selectedAppIconName = "NGCustom2"
        precondition(SGPrivacySettings.currentAppIconName(reportedName: nil) == "NGCustom2", "Keep the successful selection if UIKit still reports the old name")
        precondition(defaults.string(forKey: "sg.mod.selectedAppIconName") == "NGCustom2")
        SGPrivacySettings.selectedAppIconName = nil
        precondition(SGPrivacySettings.currentAppIconName(reportedName: "NGCustom2") == nil, "An explicit default selection must override a stale alternate name")
        SGPrivacySettings.selectedAppIconName = "SGPro"
        precondition(SGPrivacySettings.currentAppIconName(reportedName: "NGCustom2") == "SGPro", "Stock and mod pickers share selection state")
        precondition(!SGPrivacySettings.swiftpseudoPro)
        precondition(!SGPrivacySettings.allowsLocalPro(status: 1))
        precondition(SGPrivacySettings.allowsLocalPro(status: 2))
        SGPrivacySettings.swiftpseudoPro = true
        precondition(defaults.bool(forKey: "sg.mod.swiftpseudoPro"))
        precondition(SGPrivacySettings.allowsLocalPro(status: 1))
        precondition(SGPrivacySettings.allowsLocalPro(status: 2))
        SGPrivacySettings.swiftpseudoPro = false
        precondition(!SGPrivacySettings.allowsLocalPro(status: 1))
        precondition(SGPrivacySettings.allowsLocalPro(status: 2), "Disabling pseudo-Pro must preserve real Pro access")
        precondition(SGPrivacySettings.pastavibeEmojiStatusFileId == nil)
        SGPrivacySettings.pastavibeEmojiStatusFileId = Int64.max
        precondition(SGPrivacySettings.pastavibeEmojiStatusFileId == Int64.max, "Emoji document IDs must preserve all 64 bits")
        precondition((defaults.object(forKey: "sg.mod.pastavibeEmojiStatusFileId") as? NSNumber)?.int64Value == Int64.max)
        SGPrivacySettings.pastavibeEmojiStatusFileId = nil
        precondition(SGPrivacySettings.pastavibeEmojiStatusFileId == nil)
        precondition(defaults.object(forKey: "sg.mod.pastavibeEmojiStatusFileId") == nil)
        precondition(!SGPrivacySettings.ghostMode)
        precondition(SGPrivacySettings.deletedMessagesLimit == 200)
        precondition(!SGPrivacySettings.unlimitedDeletedMessages)
        for count in [0, 199, 200] {
            precondition(SGPrivacySettings.deletedMessagesOverflow(count: count) == 0)
        }
        precondition(SGPrivacySettings.deletedMessagesOverflow(count: 201) == 1)
        SGPrivacySettings.unlimitedDeletedMessages = true
        precondition(defaults.bool(forKey: "sg.mod.unlimitedDeletedMessages"))
        for count in [0, 201, 10001, 100000, Int.max] {
            precondition(SGPrivacySettings.deletedMessagesOverflow(count: count) == 0)
        }
        SGPrivacySettings.deletedMessagesLimit = 123
        precondition(SGPrivacySettings.deletedMessagesOverflow(count: 100000) == 0, "Saving a finite limit must not evict unlimited history")
        SGPrivacySettings.unlimitedDeletedMessages = false
        precondition(SGPrivacySettings.deletedMessagesLimit == 123, "Keep the saved finite limit when unlimited mode is disabled")
        precondition(SGPrivacySettings.deletedMessagesOverflow(count: 100000) == 99877)
        precondition(!defaults.bool(forKey: "sg.mod.unlimitedDeletedMessages"))
        SGPrivacySettings.deletedMessagesLimit = 3500
        precondition(SGPrivacySettings.deletedMessagesLimit == 3500)
        precondition(defaults.integer(forKey: "sg.mod.deletedMessagesLimit") == 3500)
        SGPrivacySettings.deletedMessagesLimit = 0
        precondition(SGPrivacySettings.deletedMessagesLimit == 1)
        SGPrivacySettings.deletedMessagesLimit = Int.max
        precondition(SGPrivacySettings.deletedMessagesLimit == 10000)
        defaults.set(-5, forKey: "sg.mod.deletedMessagesLimit")
        precondition(SGPrivacySettings.deletedMessagesLimit == 1)
        precondition(!SGPrivacySettings.hideOnlineAfterSend)
        SGPrivacySettings.ghostHideTyping = false
        SGPrivacySettings.ghostHideUploads = true
        precondition(!SGPrivacySettings.ghostMode, "Editing a selection must not enable the master")
        SGPrivacySettings.ghostMode = true
        precondition(SGPrivacySettings.hideOnlineAfterSend)
        SGPrivacySettings.ghostHideOnlineAfterSend = false
        precondition(!SGPrivacySettings.hideOnlineAfterSend && SGPrivacySettings.hideOnline)
        precondition(!SGPrivacySettings.suppressActivity(.typing))
        precondition(SGPrivacySettings.suppressActivity(.uploading))
        precondition(SGPrivacySettings.suppressActivity(.recording))
        precondition(SGPrivacySettings.suppressActivity(.interaction))
        precondition(!SGPrivacySettings.suppressActivity(.call))
        precondition(SGPrivacySettings.hideOnline && SGPrivacySettings.hideReadReceipts && SGPrivacySettings.hideStoryViews)
        SGPrivacySettings.ghostHideStories = false
        precondition(!SGPrivacySettings.hideStoryViews && SGPrivacySettings.hideReadReceipts)
        SGPrivacySettings.ghostMode = false
        precondition(!SGPrivacySettings.hideOnline && !SGPrivacySettings.hideReadReceipts)
        precondition(!SGPrivacySettings.suppressActivity(.uploading))
        SGPrivacySettings.ghostMode = true
        precondition(!SGPrivacySettings.ghostHideTyping && SGPrivacySettings.ghostHideUploads && !SGPrivacySettings.hideStoryViews, "Selections must survive master off/on")
        precondition(!SGPrivacySettings.videoNotes60FPS && !SGPrivacySettings.backgroundDeletedMessages)
        SGPrivacySettings.videoNotes60FPS = true
        SGPrivacySettings.backgroundDeletedMessages = true
        precondition(SGPrivacySettings.videoNotes60FPS && SGPrivacySettings.backgroundDeletedMessages)
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.set(true, forKey: "sg.mod.hideOnline")
        precondition(SGPrivacySettings.ghostMode, "Existing ghost mode must migrate")
        SGPrivacySettings.ghostMode = false
        precondition(!SGPrivacySettings.hideOnline)
        print("PASS: unlimited archive persistence and eviction policy; independent ghost controls, migration, story views, call exclusion, FPS/background preferences")
    }
}
