"""Reject Common_* presentation-string references absent from the generator input."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    "submodules/SettingsUI/Sources/Themes/ThemeSettingsController.swift",
    "Swiftgram/SGSettingsUI/Sources/SGModIconsController.swift",
    "Swiftgram/SGSettingsUI/Sources/SGModSettingsController.swift",
)

class PresentationStringsTests(unittest.TestCase):
    def test_common_strings_used_by_mod_settings_exist(self):
        resource = (ROOT / "Telegram/Telegram-iOS/en.lproj/Localizable.strings").read_text(encoding="utf-8-sig")
        keys = {key.replace(".", "_") for key in re.findall(r'^"([^"\n]+)"\s*=', resource, re.MULTILINE)}
        checked = 0
        for name in SOURCES:
            source = (ROOT / name).read_text(encoding="utf-8-sig")
            for match in re.finditer(r'\.strings\.(Common_[A-Za-z0-9_]+)\b', source):
                checked += 1
                with self.subTest(file=name, key=match.group(1)):
                    self.assertIn(match.group(1), keys, "No generated PresentationStrings member for this resource key")
        self.assertGreater(checked, 0, "No string references were checked")

if __name__ == "__main__":
    unittest.main()
