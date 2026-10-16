"""Parse our changed files with Xcode's Swift frontend, without resolving app dependencies."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
paths = [
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
print("All 16 Swift files parsed. Type checking and an IPA build are separate steps.")
