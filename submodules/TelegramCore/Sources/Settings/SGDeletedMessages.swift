import Foundation
import Postbox
import SwiftSignalKit
import SGSimpleSettings

/// Local-only marker; never serialized to the Telegram API.
public final class SGDeletedMessageAttribute: MessageAttribute {
    public let deletedAt: Int64

    public init(deletedAt: Int64) {
        self.deletedAt = deletedAt
    }

    public init(decoder: PostboxDecoder) {
        self.deletedAt = decoder.decodeInt64ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.deletedAt, forKey: "d")
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

/// Called before replaying a server deletion, in the same database transaction.
func sgArchiveDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    guard SGPrivacySettings.keepDeletedMessages else {
        return ids
    }
    var archive = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
    var changed = false
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud,
              id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup || id.peerId.namespace == Namespaces.Peer.CloudChannel,
              let message = transaction.getMessage(id),
              message.flags.contains(.Incoming), !message.text.isEmpty else {
            continue
        }
        // Secret chats, scheduled messages, disappearing and view-once content are excluded.
        if message.attributes.contains(where: { $0 is AutoremoveTimeoutMessageAttribute || $0 is AutoclearTimeoutMessageAttribute }) {
            continue
        }
        let deletedAt = Int64(Date().timeIntervalSince1970)
        if !message.attributes.contains(where: { $0 is SGDeletedMessageAttribute }) {
            transaction.updateMessage(id, update: { current in
                let attributes: [MessageAttribute] = current.attributes.filter { $0 is TextEntitiesMessageAttribute } + [SGDeletedMessageAttribute(deletedAt: deletedAt)]
                // Retain a bounded text-only bubble, without media or live actions.
                return .update(StoreMessage(id: current.id, customStableId: nil, globallyUniqueId: current.globallyUniqueId, groupingKey: nil, threadId: current.threadId, timestamp: current.timestamp, flags: StoreMessageFlags(current.flags), tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: current.author?.id, text: String(current.text.prefix(4096)), attributes: attributes, media: []))
            })
        }
        if !archive.contains(where: { $0.peerId == id.peerId.toInt64() && $0.messageId == id.id }) {
            archive.append(SGDeletedMessage(
            peerId: id.peerId.toInt64(), messageId: id.id,
            chatTitle: sgArchivePeerTitle(transaction.getPeer(id.peerId)),
            author: sgArchivePeerTitle(message.author),
            text: String(message.text.prefix(4096)), timestamp: message.timestamp,
                deletedAt: deletedAt
            ))
            changed = true
        }
    }
    // Bound both row count and text storage; media are never copied into the archive.
    var textBytes = archive.reduce(0) { $0 + $1.text.utf8.count }
    while archive.count > 200 || textBytes > 512 * 1024 {
        let expired = archive.removeFirst()
        textBytes -= expired.text.utf8.count
        sgRemoveRetainedRows(transaction: transaction, messages: [expired])
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

public func sgRemoveRetainedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let messages = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
        sgRemoveRetainedRows(transaction: transaction, messages: messages)
    }
}

public func sgClearDeletedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let messages = transaction.getPreferencesEntry(key: sgDeletedMessagesKey)?.get(SGDeletedMessages.self)?.messages ?? []
        sgRemoveRetainedRows(transaction: transaction, messages: messages)
        transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in nil })
    }
}
