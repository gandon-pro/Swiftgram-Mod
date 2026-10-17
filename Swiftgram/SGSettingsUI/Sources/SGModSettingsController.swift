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
    case camera
}

private enum SGModToggle: Hashable {
    case ghost, deleted, background, video60, online, afterSend, typing, recording, uploads, reads, stories, interactions
}

private enum SGModLink: Hashable {
    case archive
}

private typealias SGModEntry = SGItemListUIEntry<SGModSection, SGModToggle, String, String, SGModLink, String>

public func sgModSettingsController(context: AccountContext) -> ViewController {
    let changed = ValuePromise(true, ignoreRepeated: false)
    var pushImpl: ((ViewController) -> Void)?
    var archiveLimitInput = String(SGPrivacySettings.deletedMessagesLimit)
    let arguments = SGItemListArguments<SGModToggle, String, String, SGModLink, String>(context: context, setBoolValue: { setting, value in
        switch setting {
        case .ghost:
            SGPrivacySettings.ghostMode = value
        case .online:
            SGPrivacySettings.ghostHideOnline = value
        case .afterSend:
            SGPrivacySettings.ghostHideOnlineAfterSend = value
        case .typing:
            SGPrivacySettings.ghostHideTyping = value
        case .recording:
            SGPrivacySettings.ghostHideRecording = value
        case .uploads:
            SGPrivacySettings.ghostHideUploads = value
        case .reads:
            SGPrivacySettings.ghostHideReadReceipts = value
        case .stories:
            SGPrivacySettings.ghostHideStories = value
        case .interactions:
            SGPrivacySettings.ghostHideInteractions = value
        case .background:
            SGPrivacySettings.backgroundDeletedMessages = value
        case .video60:
            SGPrivacySettings.videoNotes60FPS = value
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
    }, action: { action in
        if action == "saveArchiveLimit", let limit = Int(archiveLimitInput), (1 ... 10000).contains(limit) {
            SGPrivacySettings.deletedMessagesLimit = limit
            archiveLimitInput = String(limit)
            let _ = sgTrimDeletedMessages(postbox: context.account.postbox).startStandalone()
            changed.set(true)
        }
    }, searchInput: { text in
        // Edit a draft. Never trim while typing "1000" through "1", "10", etc.
        archiveLimitInput = String(text.prefix(6))
        changed.set(true)
    })
    let signal = combineLatest(context.sharedContext.presentationData, changed.get())
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ru = data.strings.baseLanguageCode.hasPrefix("ru")
        let counter = SGItemListCounter()
        var entries: [SGModEntry] = []
        entries.append(.header(id: counter.count, section: .privacy, text: ru ? "Приватность" : "Privacy", badge: nil))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .ghost, value: SGPrivacySettings.ghostMode, text: ru ? "Режим призрака" : "Ghost mode", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .online, value: SGPrivacySettings.ghostHideOnline, text: ru ? "Скрывать онлайн" : "Hide online status", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .afterSend, value: SGPrivacySettings.ghostHideOnlineAfterSend, text: ru ? "Переходить в офлайн после отправки" : "Request offline after sending", enabled: true))
        entries.append(.notice(id: counter.count, section: .privacy, text: ru ? "После отправки текста, файла или альбома клиент повторно запрашивает офлайн. Сервер Telegram всё равно может кратковременно показывать онлайн получателю; полной невидимости при отправке нет." : "After a text, file or album is sent, requests offline again. Telegram may still briefly show you online to the recipient; sending cannot be completely invisible."))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .typing, value: SGPrivacySettings.ghostHideTyping, text: ru ? "Скрывать набор текста" : "Hide typing", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .recording, value: SGPrivacySettings.ghostHideRecording, text: ru ? "Скрывать запись голоса и кружков" : "Hide voice and video recording", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .uploads, value: SGPrivacySettings.ghostHideUploads, text: ru ? "Скрывать загрузку файлов и медиа" : "Hide file and media upload indicators", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .reads, value: SGPrivacySettings.ghostHideReadReceipts, text: ru ? "Скрывать прочтение сообщений" : "Hide message read receipts", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .stories, value: SGPrivacySettings.ghostHideStories, text: ru ? "Скрывать просмотр историй" : "Hide story views", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .interactions, value: SGPrivacySettings.ghostHideInteractions, text: ru ? "Скрывать выбор стикеров и другие индикаторы" : "Hide sticker and interaction indicators", enabled: true))
        entries.append(.notice(id: counter.count, section: .privacy, text: ru ? "Выберите скрываемые индикаторы. Главный переключатель сохраняет этот выбор. Отправленное сообщение или файл остаётся видимым получателю; уже отправленные отметки отменить нельзя." : "Choose which activity indicators to hide. The master switch preserves your selections. Sent messages and files remain visible to the recipient; already sent receipts cannot be undone."))
        entries.append(.toggle(id: counter.count, section: .deleted, settingName: .deleted, value: SGPrivacySettings.keepDeletedMessages, text: ru ? "Удалённые сообщения" : "Deleted messages", enabled: true))
        entries.append(.toggle(id: counter.count, section: .deleted, settingName: .background, value: SGPrivacySettings.backgroundDeletedMessages, text: ru ? "Обрабатывать удалёнки в фоне" : "Process deletions in background", enabled: SGPrivacySettings.keepDeletedMessages))
        entries.append(.notice(id: counter.count, section: .deleted, text: ru ? "Обработка продолжается в отведённое iOS фоновое время и при пробуждении push-уведомлением. При возврате обновления синхронизируются. После принудительного закрытия постоянное сканирование недоступно; сообщения, не полученные этим клиентом, восстановить нельзя." : "Processes updates during iOS background time and push wakeups, then synchronizes on return. Continuous scanning after force-quitting is unavailable; messages never received by this client cannot be recovered."))
        entries.append(.disclosure(id: counter.count, section: .deleted, link: .archive, text: ru ? "Архив удалённых сообщений" : "Deleted message archive"))
        entries.append(.searchInput(id: counter.count, section: .deleted, title: NSAttributedString(string: ru ? "Лимит архива: " : "Archive limit: "), text: archiveLimitInput, placeholder: "200"))
        let validArchiveLimit = Int(archiveLimitInput).map { (1 ... 10000).contains($0) } ?? false
        entries.append(.action(id: counter.count, section: .deleted, actionType: "saveArchiveLimit", text: ru ? "Сохранить лимит архива" : "Save archive limit", kind: validArchiveLimit ? .generic : .disabled))
        entries.append(.notice(id: counter.count, section: .deleted, text: ru ? "Введите целое число от 1 до 10000 и нажмите «Сохранить». Текущий лимит: \(SGPrivacySettings.deletedMessagesLimit). При уменьшении старейшие записи удаляются из архива и чатов." : "Enter an integer from 1 to 10000, then tap Save. Current limit: \(SGPrivacySettings.deletedMessagesLimit). Reducing it removes the oldest retained entries from the archive and chats."))
        entries.append(.notice(id: counter.count, section: .deleted, text: ru ? "Удалённые сообщения остаются в чате с прозрачностью 50%: до \(SGPrivacySettings.deletedMessagesLimit) записей, включая обычное автоудаление в облачных чатах. Сохраняются текст и ссылки на обычные медиа; не загруженные файлы могут быть недоступны. Секретные чаты, одноразовые и самоуничтожающиеся медиа исключены. Выключение убирает сохранённые сообщения из чата; архив очищается отдельно." : "Deleted messages remain at 50% opacity: up to \(SGPrivacySettings.deletedMessagesLimit) entries, including ordinary cloud-chat auto-delete. Keeps text and ordinary media references; files not downloaded may be unavailable. Secret chats, view-once and self-destructing media are excluded. Switching off removes retained chat messages; clear the archive separately."))
        entries.append(.toggle(id: counter.count, section: .camera, settingName: .video60, value: SGPrivacySettings.videoNotes60FPS, text: ru ? "Кружки: 60 FPS" : "Video messages: 60 FPS", enabled: true))
        entries.append(.notice(id: counter.count, section: .camera, text: ru ? "Выключено — стандартные 30 FPS. В режиме 60 FPS используется одна камера: фронтальная или задняя, с переключением при записи. Камера должна поддерживать формат 60 FPS. Изменение применяется при следующем открытии записи кружка." : "Off uses the default 30 FPS. 60 FPS uses one camera at a time, front or back, with switching while recording. A supported 60 FPS camera format is required. Changes apply the next time video-message recording opens."))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text("Nigga"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        return (state, (ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, ensureVisibleItemTag: nil), arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    return controller
}
