import Foundation

@main
struct SGPrivacySettingsTests {
    static func main() {
        let defaults = UserDefaults.standard
        let keys = ["ghostEnabled", "hideOnline", "hideTyping", "hideReadReceipts", "hideRecording", "hideUploads", "hideStoryViews", "hideInteractions", "keepDeletedMessages", "backgroundDeletedMessages", "videoNotes60FPS"].map { "sg.mod." + $0 }
        let old = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, old) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        for key in keys { defaults.removeObject(forKey: key) }
        precondition(!SGPrivacySettings.ghostMode)
        SGPrivacySettings.ghostHideTyping = false
        SGPrivacySettings.ghostHideUploads = true
        precondition(!SGPrivacySettings.ghostMode, "Editing a selection must not enable the master")
        SGPrivacySettings.ghostMode = true
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
