import Foundation

@main
struct SGPrivacySettingsTests {
    static func main() {
        let defaults = UserDefaults.standard
        let keys = ["selectedAppIconName", "swiftpseudoPro", "ghostEnabled", "hideOnline", "hideOnlineAfterSend", "deletedMessagesLimit", "hideTyping", "hideReadReceipts", "hideRecording", "hideUploads", "hideStoryViews", "hideInteractions", "keepDeletedMessages", "backgroundDeletedMessages", "videoNotes60FPS"].map { "sg.mod." + $0 }
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
        precondition(!SGPrivacySettings.ghostMode)
        precondition(SGPrivacySettings.deletedMessagesLimit == 200)
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
        print("PASS: independent ghost controls, master persistence, migration, story views, call exclusion, FPS/background preferences")
    }
}
