import Foundation
import SGSimpleSettings
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import AccountContext

private struct SGModIconArguments {
    let select: (Int) -> Void
}

private enum SGModIconEntry: ItemListNodeEntry {
    case icon(Int, String, Bool, Bool)
    case notice(String)

    var section: ItemListSectionId { return 0 }
    var stableId: Int {
        switch self {
        case let .icon(index, _, _, _): return index
        case .notice: return 4
        }
    }
    static func < (lhs: SGModIconEntry, rhs: SGModIconEntry) -> Bool { return lhs.stableId < rhs.stableId }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SGModIconArguments
        switch self {
        case let .icon(index, title, selected, enabled):
            let image: UIImage?
            if index == 0 {
                image = UIImage(bundleImageName: "ModPrivacy")
            } else if let path = Bundle.main.path(forResource: "NGCustom\(index)-60@3x", ofType: "png") {
                image = UIImage(contentsOfFile: path)
            } else {
                image = nil
            }
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, icon: image, iconSize: CGSize(width: 40, height: 40), title: title, style: .right, checked: selected, enabled: enabled, zeroSeparatorInsets: false, sectionId: self.section, action: { arguments.select(index) })
        case let .notice(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

public func sgModIconsController(context: AccountContext) -> ViewController {
    let changed = ValuePromise(true, ignoreRepeated: false)
    var changing = false
    // UIKit may return the previous alternateIconName inside its completion.
    // Keep the last successful request as the UI's state instead of rereading it.
    var selectedIconName = SGPrivacySettings.currentAppIconName(reportedName: UIApplication.shared.alternateIconName)
    var presentImpl: ((ViewController) -> Void)?
    let arguments = SGModIconArguments(select: { index in
        guard !changing, UIApplication.shared.supportsAlternateIcons else { return }
        let name: String? = index == 0 ? nil : "NGCustom\(index)"
        changing = true
        changed.set(true)
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                changing = false
                if error == nil {
                    selectedIconName = name
                    SGPrivacySettings.selectedAppIconName = name
                }
                changed.set(true)
                if let error {
                    let data = context.sharedContext.currentPresentationData.with { $0 }
                    let ru = data.strings.baseLanguageCode.hasPrefix("ru")
                    presentImpl?(textAlertController(context: context, title: ru ? "Не удалось сменить иконку" : "Could not change icon", text: error.localizedDescription, actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]))
                }
            }
        }
    })
    let signal = combineLatest(context.sharedContext.presentationData, changed.get())
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let ru = data.strings.baseLanguageCode.hasPrefix("ru")
        let selected = selectedIconName
        let supported = UIApplication.shared.supportsAlternateIcons
        let alternatives = (Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])?["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
        var entries: [SGModIconEntry] = []
        entries.append(.icon(0, ru ? "Стандартная" : "Default", selected == nil, supported && !changing))
        for index in 1 ... 3 {
            let name = "NGCustom\(index)"
            entries.append(.icon(index, ru ? "Иконка \(index)" : "Icon \(index)", selected == name, supported && !changing && alternatives[name] != nil))
        }
        let notice: String
        if !supported {
            notice = ru ? "В этой установке iOS не разрешает смену иконки приложения." : "iOS does not allow alternate icons in this installation."
        } else if alternatives["NGCustom1"] == nil {
            notice = ru ? "Эти иконки появятся после установки новой сборки IPA." : "These icons require installing the updated IPA."
        } else {
            notice = ru ? "Меняет иконку приложения на рабочем столе. Стандартная возвращает исходный портрет. Верхний значок Niggagram остаётся прежним." : "Changes the Home Screen app icon. Default restores the original portrait. The top Niggagram badge stays unchanged."
        }
        entries.append(.notice(notice))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(ru ? "Иконка приложения" : "App icon"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        return (state, (ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, ensureVisibleItemTag: nil), arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    presentImpl = { [weak controller] next in controller?.present(next, in: .window(.root)) }
    return controller
}
