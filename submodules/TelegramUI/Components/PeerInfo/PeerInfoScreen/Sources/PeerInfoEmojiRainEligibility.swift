import Foundation
import TelegramCore

extension PeerInfoEmojiRainOverlay {
    static func isEnabled(for user: TelegramUser) -> Bool {
        let enabledUsernames: Set<String> = ["pastavibecoding"]
        var usernames = user.usernames.filter { $0.isActive }.map { $0.username }
        if let addressName = user.addressName {
            usernames.append(addressName)
        }
        return usernames.contains { enabledUsernames.contains($0.lowercased()) }
    }
}
