import Postbox
import SGSimpleSettings

/// Client-only decoration; never changes the peer or its server-side status.
public func sgLocalModEmojiStatus(peer: Peer) -> PeerEmojiStatus? {
    guard let user = peer as? TelegramUser,
          user.username?.lowercased() == "pastavibecoding" || user.usernames.contains(where: { $0.flags.contains(.isActive) && $0.username.lowercased() == "pastavibecoding" }),
          let id = SGPrivacySettings.pastavibeEmojiStatusFileId else { return nil }
    return PeerEmojiStatus(content: .emoji(fileId: id), expirationDate: nil)
}

public func sgLocalModEmojiStatus(peer: EnginePeer) -> PeerEmojiStatus? {
    return sgLocalModEmojiStatus(peer: peer._asPeer())
}
