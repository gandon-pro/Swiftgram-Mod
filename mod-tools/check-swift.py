"""Parse our changed files with Xcode's Swift frontend, without resolving app dependencies."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
paths = [
    "submodules/Camera/Sources/CameraUtils.swift",
    "submodules/TelegramCore/Sources/State/PendingMessageManager.swift",
    "submodules/TelegramCore/Sources/State/ManagedAutoremoveMessageOperations.swift",
    "submodules/TelegramUI/Components/Resources/FetchVideoMediaResource/Sources/FetchVideoMediaResource.swift",
    "submodules/Display/Source/WindowContent.swift",
    "submodules/Camera/Sources/Camera.swift",
    "submodules/Camera/Sources/CameraDevice.swift",
    "submodules/Camera/Sources/CameraOutput.swift",
    "submodules/ICloudResources/Sources/ICloudFileAccess.swift",
    "submodules/ICloudResources/Sources/ICloudResources.swift",
    "submodules/TelegramUI/Sources/ChatControllerOpenAttachmentMenu.swift",
    "submodules/TelegramCore/Sources/State/ManagedSynchronizeViewStoriesOperations.swift",
    "submodules/TelegramCore/Sources/TelegramEngine/Messages/Stories.swift",
    "mod-tools/tests/SGPrivacySettingsTests.swift",
    "mod-tools/tests/ICloudFileAccessTests.swift",
    "Swiftgram/SGSimpleSettings/Sources/SGAppStorage.swift",
    "submodules/TelegramUI/Sources/AppDelegate.swift",
    "mod-tools/tests/SGAppStorageTests.swift",
    "Swiftgram/SGSettingsUI/Sources/SGModSettingsController.swift",
    "submodules/TelegramCore/Sources/Account/AccountManager.swift",
    "submodules/TelegramCore/Sources/State/HistoryViewStateValidation.swift",
    "submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesSettings.swift",
    "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift",
    "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift",
    "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift",
    "submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift",
    "Swiftgram/SGItemListUI/Sources/SGItemListUI.swift",
    "Swiftgram/SGSettingsUI/Sources/SGDeletedMessagesController.swift",
    "Swiftgram/SGSettingsUI/Sources/SGSettingsController.swift",
    "Swiftgram/SGSimpleSettings/Sources/SGPrivacySettings.swift",
    "submodules/TelegramCore/Sources/Settings/SGDeletedMessages.swift",
    "submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift",
    "submodules/TelegramCore/Sources/State/AccountViewTracker.swift",
    "submodules/TelegramCore/Sources/State/ManagedAccountPresence.swift",
    "submodules/TelegramCore/Sources/State/ManagedConsumePersonalMessagesActions.swift",
    "submodules/TelegramCore/Sources/State/ManagedLocalInputActivities.swift",
    "submodules/TelegramCore/Sources/State/ManagedSynchronizeConsumeMessageContentsOperations.swift",
    "submodules/TelegramCore/Sources/State/ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift",
    "submodules/TelegramCore/Sources/State/SynchronizePeerReadState.swift",
    "submodules/TelegramCore/Sources/TelegramEngine/Messages/ApplyMaxReadIndexInteractively.swift",
    "submodules/TelegramCore/Sources/TelegramEngine/Messages/MarkAllChatsAsRead.swift",
    "submodules/TelegramCore/Sources/TelegramEngine/Messages/ReplyThreadHistory.swift",
]
for path in paths:
    subprocess.run(["xcrun", "swiftc", "-frontend", "-parse", str(root / path)], check=True, cwd=root)
    print("Parsed:", path)
print(f"All {len(paths)} Swift files parsed. Type checking and an IPA build are separate steps.")
