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
    case ghost, deleted, background, video60, online, typing, recording, uploads, reads, stories, interactions
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
        case .online:
            SGPrivacySettings.ghostHideOnline = value
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
    })
    let signal = combineLatest(context.sharedContext.presentationData, changed.get())
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ru = data.strings.baseLanguageCode.hasPrefix("ru")
        let counter = SGItemListCounter()
        var entries: [SGModEntry] = []
        entries.append(.header(id: counter.count, section: .privacy, text: ru ? "Приватность" : "Privacy", badge: nil))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .ghost, value: SGPrivacySettings.ghostMode, text: ru ? "Режим призрака" : "Ghost mode", enabled: true))
        entries.append(.toggle(id: counter.count, section: .privacy, settingName: .online, value: SGPrivacySettings.ghostHideOnline, text: ru ? "Скрывать онлайн" : "Hide online status", enabled: true))
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
        entries.append(.notice(id: counter.count, section: .deleted, text: ru ? "Удалённые сообщения остаются в чате с прозрачностью 50%: до 200 записей, текст и ссылки на обычные медиа. Не загруженные до удаления файлы могут быть недоступны. Секретные и исчезающие сообщения исключены. Выключение убирает сохранённые сообщения из чата; архив очищается отдельно." : "Deleted messages remain at 50% opacity: up to 200 entries with text and ordinary media references. Files not downloaded before deletion may be unavailable. Secret and disappearing messages are excluded. Switching off removes retained chat messages; clear the archive separately."))
        entries.append(.toggle(id: counter.count, section: .camera, settingName: .video60, value: SGPrivacySettings.videoNotes60FPS, text: ru ? "Кружки: 60 FPS" : "Video messages: 60 FPS", enabled: true))
        entries.append(.notice(id: counter.count, section: .camera, text: ru ? "Выключено — стандартные 30 FPS. 60 FPS применяется к новой записи, если выбранная камера поддерживает этот режим. Двойная камера и неподдерживаемые форматы используют доступную частоту." : "Off uses the default 30 FPS. 60 FPS applies to new recordings when supported by the selected camera. Dual-camera and unsupported formats use the available rate."))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text("Nigga"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        return (state, (ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, ensureVisibleItemTag: nil), arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    return controller
}
