import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import SGItemListUI
import SGSimpleSettings

private enum SGModSection: Int32, SGItemListSection {
    case privacy
    case deleted
}

private enum SGModToggle: Hashable {
    case ghost
    case deleted
}

private enum SGModLink: Hashable {
    case archive
}

private typealias SGModEntry = SGItemListUIEntry<SGModSection, SGModToggle, String, String, SGModLink, String>

public func sgModSettingsController(context: AccountContext) -> ViewController {
    let changed = ValuePromise(true, ignoreRepeated: false)
    var pushImpl: ((ViewController) -> Void)?
    let arguments = SGItemListArguments<SGModToggle, String, String, SGModLink, String>(context: context, setBoolValue: { setting, value in
        switch setting {
        case .ghost:
            SGPrivacySettings.ghostMode = value
        case .deleted:
            SGPrivacySettings.keepDeletedMessages = value
            if !value {
                // Remove only locally retained, server-deleted rows from this account.
                let _ = sgRemoveRetainedMessages(postbox: context.account.postbox).start()
            }
        }
        changed.set(true)
    }, openDisclosureLink: { _ in
        pushImpl?(sgDeletedMessagesController(context: context))
    })
    let signal = combineLatest(context.sharedContext.presentationData, changed.get())
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ru = data.strings.baseLanguageCode.hasPrefix("ru")
        let counter = SGItemListCounter()
        var entries: [SGModEntry] = []
        entries.append(.header(id: counter.count, section: .privacy, text: ru ? "Приватность" : "Privacy", badge: nil))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .ghost, value: SGPrivacySettings.ghostMode, text: ru ? "Режим призрака" : "Ghost mode", enabled: true))
        entries.append(.notice(id: counter.count, section: .privacy, text: ru ? "Скрывает онлайн, набор текста и отметки прочтения в облачных чатах в этом клиенте. Истории, секретные чаты, отправка сообщений и звонки могут раскрывать активность." : "Hides online status, typing and cloud-chat read receipts in this client. Stories, secret chats, sending messages and calls can reveal activity."))
        entries.append(.toggle(id: counter.count, section: .deleted, settingName: .deleted, value: SGPrivacySettings.keepDeletedMessages, text: ru ? "Удалённые сообщения" : "Deleted messages", enabled: true))
        entries.append(.disclosure(id: counter.count, section: .deleted, link: .archive, text: ru ? "Архив удалённых сообщений" : "Deleted message archive"))
        entries.append(.notice(id: counter.count, section: .deleted, text: ru ? "Уже полученный текст удалённых входящих сообщений остаётся в чате с прозрачностью 50%. До 200 сообщений; без медиа, секретных и исчезающих сообщений. При выключении сохранённые удалённые сообщения убираются из чата. Архив можно очистить отдельно." : "Already received incoming text remains in the chat at 50% opacity. Up to 200 messages; media, secret and disappearing messages are excluded. Switching off removes retained messages from the chat. The archive can be cleared separately."))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text("Nigga"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        return (state, (ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, ensureVisibleItemTag: nil), arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    return controller
}
