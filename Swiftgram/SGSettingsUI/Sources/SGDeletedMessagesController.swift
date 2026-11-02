import Foundation
import SGSimpleSettings
import Postbox
import PresentationDataUtils
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import SGItemListUI

private enum SGArchiveSection: Int32, SGItemListSection {
    case actions
    case messages
}

private enum SGArchiveAction: Hashable {
    case clear
}

private typealias SGArchiveEntry = SGItemListUIEntry<SGArchiveSection, String, String, String, String, SGArchiveAction>

func sgDeletedMessagesController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?
    let arguments = SGItemListArguments<String, String, String, String, SGArchiveAction>(context: context, action: { action in
        switch action {
        case .clear:
            let data = context.sharedContext.currentPresentationData.with { $0 }
            let ru = data.strings.baseLanguageCode.hasPrefix("ru")
            presentImpl?(textAlertController(context: context, title: ru ? "Очистить архив?" : "Clear archive?", text: ru ? "Сохранённый текст удалится из архива и полупрозрачных сообщений в чатах этого аккаунта." : "Saved text and translucent retained bubbles will be removed from this account.", actions: [
                TextAlertAction(type: .genericAction, title: data.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: data.strings.Common_Delete, action: {
                    let _ = sgClearDeletedMessages(postbox: context.account.postbox).start()
                })
            ]))
        }
    })
    let signal = combineLatest(context.sharedContext.presentationData, context.account.postbox.preferencesView(keys: [sgDeletedMessagesKey]))
    |> map { data, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ru = data.strings.baseLanguageCode.hasPrefix("ru")
        let messages = view.values[sgDeletedMessagesKey]?.get(SGDeletedMessages.self)?.messages ?? []
        let counter = SGItemListCounter()
        var entries: [SGArchiveEntry] = []
        entries.append(.header(id: counter.count, section: .actions, text: ru ? "Локальный архив · \(messages.count)/\(SGPrivacySettings.deletedMessagesLimit)" : "Local archive · \(messages.count)/\(SGPrivacySettings.deletedMessagesLimit)", badge: nil))
        entries.append(.action(id: counter.count, section: .actions, actionType: .clear, text: ru ? "Очистить архив" : "Clear archive", kind: .destructive))
        if messages.isEmpty {
            entries.append(.notice(id: counter.count, section: .messages, text: ru ? "Пока нет сохранённых сообщений. Включите удалённые сообщения в разделе Nigga. Восстановить сообщения, которые этот клиент не получал, нельзя." : "No saved messages yet. Enable deleted messages in Nigga settings. Messages this client never received cannot be recovered."))
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: data.strings.baseLanguageCode)
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            for message in messages.reversed() {
                let date = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp)))
                entries.append(.header(id: counter.count, section: .messages, text: "\(message.chatTitle) · \(date)", badge: nil))
                entries.append(.plainNotice(id: counter.count, section: .messages, text: "\(message.author)\n\(message.text)"))
            }
        }
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(ru ? "Удалённые сообщения" : "Deleted messages"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let list = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, ensureVisibleItemTag: nil)
        return (state, (list, arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
