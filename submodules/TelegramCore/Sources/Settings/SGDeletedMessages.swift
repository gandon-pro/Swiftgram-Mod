import Foundation
import Postbox
import SwiftSignalKit
import SGSimpleSettings

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
func sgArchiveDeletedMessages(transaction: Transaction, ids: [MessageId]) {
    guard SGPrivacySettings.keepDeletedMessages else {
        return
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
        if archive.contains(where: { $0.peerId == id.peerId.toInt64() && $0.messageId == id.id }) {
            continue
        }
        archive.append(SGDeletedMessage(
            peerId: id.peerId.toInt64(), messageId: id.id,
            chatTitle: sgArchivePeerTitle(transaction.getPeer(id.peerId)),
            author: sgArchivePeerTitle(message.author),
            text: String(message.text.prefix(4096)), timestamp: message.timestamp,
            deletedAt: Int64(Date().timeIntervalSince1970)
        ))
        changed = true
    }
    guard changed else { return }
    // Bound both row count and text storage; media are never copied into the archive.
    var textBytes = archive.reduce(0) { $0 + $1.text.utf8.count }
    while archive.count > 200 || textBytes > 512 * 1024 {
        textBytes -= archive.removeFirst().text.utf8.count
    }
    transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in
        return PreferencesEntry(SGDeletedMessages(messages: archive))
    })
}

public func sgClearDeletedMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: sgDeletedMessagesKey, { _ in nil })
    }
}
