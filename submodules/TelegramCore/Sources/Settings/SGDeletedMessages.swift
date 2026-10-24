import Foundation
import Postbox
import SwiftSignalKit
import SGSimpleSettings

/// Local-only marker; never serialized to the Telegram API.
public final class SGDeletedMessageAttribute: MessageAttribute {
    public let deletedAt: Int64
    public let isTimedMedia: Bool

    public init(deletedAt: Int64, isTimedMedia: Bool = false) {
        self.deletedAt = deletedAt
        self.isTimedMedia = isTimedMedia
    }

    public init(decoder: PostboxDecoder) {
        self.deletedAt = decoder.decodeInt64ForKey("d", orElse: 0)
        self.isTimedMedia = decoder.decodeInt32ForKey("t", orElse: 0) != 0
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.deletedAt, forKey: "d")
        encoder.encodeInt32(self.isTimedMedia ? 1 : 0, forKey: "t")
    }
}

private func sgRemoveRetainedRows(transaction: Transaction, messages: [SGDeletedMessage]) {
    let ids = messages.map { MessageId(peerId: PeerId($0.peerId), namespace: Namespaces.Message.Cloud, id: $0.messageId) }
    let retained = ids.filter { id in
        transaction.getMessage(id)?.attributes.contains(where: { $0 is SGDeletedMessageAttribute }) == true
    }
    transaction.deleteMessages(retained, forEachMedia: nil)
}

public struct SGDeletedMessage: Codable, Equatable {
    public let peerId: Int64
    public let messageId: Int32
    public let chatTitle: String
    public let author: String
    public let text: String
    public let timestamp: Int32
    public let deletedAt: Int64
}

// Account-local Postbox data, removed along with that account's database.
public let sgDeletedMessagesKey = ValueBoxKey("swiftgram.mod.deleted-messages.v1")

public struct SGDeletedMessages: Codable, Equatable {
    public let messages: [SGDeletedMessage]

    public init(messages: [SGDeletedMessage] = []) {
        self.messages = messages
    }
}

private func sgArchivePeerTitle(_ peer: Peer?) -> String {
    if let user = peer as? TelegramUser {
        let name = [user.firstName, user.lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? (user.username ?? String(user.id.toInt64())) : name
    } else if let group = peer as? TelegramGroup {
        return group.title
    } else if let channel = peer as? TelegramChannel {
        return channel.title
    }
    return "—"
}

/// Timed cloud photos/videos only; ordinary auto-delete is a separate path.
public func sgIsTimedPhotoOrVideo(_ message: Message) -> Bool {
    guard message.id.namespace == Namespaces.Message.Cloud,
          message.id.peerId.namespace != Namespaces.Peer.SecretChat,
          message.attributes.contains(where: {
              $0 is AutoclearTimeoutMessageAttribute || ($0 as? AutoremoveTimeoutMessageAttribute)?.timeout == viewOnceTimeout || ($0 as? SGDeletedMessageAttribute)?.isTimedMedia == true
          }) else { return false }
    return message.media.contains { media in
        if media is TelegramMediaImage { return true }
        if let file = media as? TelegramMediaFile { return file.isVideo }
        return false
    }
}

public func sgCanSaveTimedMedia(_ message: Message) -> Bool {
    return SGPrivacySettings.keepTimedMedia && sgIsTimedPhotoOrVideo(message)
}

/// Called before replaying a server deletion, in the same database transaction.
func sgArchiveDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    guard SGPrivacySettings.keepDeletedMessages || SGPrivacySettings.keepTimedMedia else {
        return ids
    }
    var archive = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
    var changed = false
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud,
              id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup || id.peerId.namespace == Namespaces.Peer.CloudChannel,
              let message = transaction.getMessage(id),
              !message.text.isEmpty || message.media.contains(where: { $0 is TelegramMediaImage || $0 is TelegramMediaFile }) else {
            continue
        }
        let timedMedia = sgIsTimedPhotoOrVideo(message)
        let hasExpiringMedia = message.attributes.contains(where: {
            $0 is AutoclearTimeoutMessageAttribute || ($0 as? AutoremoveTimeoutMessageAttribute)?.timeout == viewOnceTimeout
        })
        guard SGPrivacySettings.shouldRetainMessage(isTimedMedia: timedMedia, hasExpiringMedia: hasExpiringMedia) else { continue }
        let deletedAt = Int64(Date().timeIntervalSince1970)
        if !message.attributes.contains(where: { $0 is SGDeletedMessageAttribute }) {
            transaction.updateMessage(id, update: { current in
                let attributes: [MessageAttribute] = current.attributes.filter { $0 is TextEntitiesMessageAttribute } + [SGDeletedMessageAttribute(deletedAt: deletedAt, isTimedMedia: timedMedia)]
                // Keep resource references so cached photo/video content remains
                // available. Secret-chat rows are excluded above.
                let media = current.media.filter { $0 is TelegramMediaImage || $0 is TelegramMediaFile }
                return .update(StoreMessage(id: current.id, customStableId: nil, globallyUniqueId: current.globallyUniqueId, groupingKey: nil, threadId: current.threadId, timestamp: current.timestamp, flags: StoreMessageFlags(current.flags), tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: current.author?.id, text: String(current.text.prefix(4096)), attributes: attributes, media: media))
            })
        }
        if !archive.contains(where: { $0.peerId == id.peerId.toInt64() && $0.messageId == id.id }) {
            archive.append(SGDeletedMessage(
            peerId: id.peerId.toInt64(), messageId: id.id,
            chatTitle: sgArchivePeerTitle(transaction.getPeer(id.peerId)),
            author: sgArchivePeerTitle(message.author),
            text: message.text.isEmpty ? "[Media / Медиа]" : String(message.text.prefix(4096)), timestamp: message.timestamp,
                deletedAt: deletedAt
            ))
            changed = true
        }
    }
    let overflow = SGPrivacySettings.deletedArchiveOverflow(count: archive.count)
    if overflow > 0 {
        sgRemoveRetainedRows(transaction: transaction, messages: Array(archive.prefix(overflow)))
        archive.removeFirst(overflow)
        changed = true
    }
    if changed {
        transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in
            return PreferencesEntry(SGDeletedMessages(messages: archive))
        })
    }
    return ids.filter { id in
        transaction.getMessage(id)?.attributes.contains(where: { $0 is SGDeletedMessageAttribute }) != true
    }
}

public func sgTrimDeletedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var messages = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
        let overflow = SGPrivacySettings.deletedArchiveOverflow(count: messages.count)
        guard overflow > 0 else { return }
        sgRemoveRetainedRows(transaction: transaction, messages: Array(messages.prefix(overflow)))
        messages.removeFirst(overflow)
        transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in PreferencesEntry(SGDeletedMessages(messages: messages)) })
    }
}

public func sgRemoveRetainedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let messages = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
        let disabled = messages.filter { entry in
            let id = MessageId(peerId: PeerId(entry.peerId), namespace: Namespaces.Message.Cloud, id: entry.messageId)
            guard let marker = transaction.getMessage(id)?.attributes.first(where: { $0 is SGDeletedMessageAttribute }) as? SGDeletedMessageAttribute else { return false }
            return marker.isTimedMedia ? !SGPrivacySettings.keepTimedMedia : !SGPrivacySettings.keepDeletedMessages
        }
        sgRemoveRetainedRows(transaction: transaction, messages: disabled)
    }
}

public func sgClearDeletedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let messages = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
        sgRemoveRetainedRows(transaction: transaction, messages: messages)
        transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in nil })
    }
}

/// Persists the explicit copy operation across restarts; never sent as an API attribute.
public final class SGProtectedMessageCopyAttribute: MessageAttribute {
    public init() {}
    public init(decoder: PostboxDecoder) {}
    public func encode(_ encoder: PostboxEncoder) {}
}

/// Ordinary cloud text/photos/files only. Expiring media keeps its normal restrictions.
public func sgCanCopyProtectedMessage(_ message: Message) -> Bool {
    guard SGPrivacySettings.copyProtectedMessages,
          message.id.namespace == Namespaces.Message.Cloud,
          message.id.peerId.namespace != Namespaces.Peer.SecretChat,
          !message.containsSecretMedia,
          !message.flags.isSending, !message.flags.contains(.Failed) else { return false }
    if message.attributes.contains(where: { $0 is AutoclearTimeoutMessageAttribute }) { return false }
    return message.media.allSatisfy { $0 is TelegramMediaImage || $0 is TelegramMediaFile || $0 is TelegramMediaWebpage }
        && (!message.text.isEmpty || message.media.contains(where: { $0 is TelegramMediaImage || $0 is TelegramMediaFile }))
}

/// Client-only decoration. Never changes the account's Telegram Premium status.
public func sgLocalModEmojiStatus(peer: Peer) -> PeerEmojiStatus? {
    guard let user = peer as? TelegramUser,
          user.username?.lowercased() == "pastavibecoding" || user.usernames.contains(where: { $0.flags.contains(.isActive) && $0.username.lowercased() == "pastavibecoding" }),
          let id = SGPrivacySettings.pastavibeEmojiStatusFileId else { return nil }
    return PeerEmojiStatus(content: .emoji(fileId: id), expirationDate: nil)
}

public func sgLocalModEmojiStatus(peer: EnginePeer) -> PeerEmojiStatus? {
    return sgLocalModEmojiStatus(peer: peer._asPeer())
}
