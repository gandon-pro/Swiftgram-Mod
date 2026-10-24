"""Verify alternate icon packaging without compiling or signing an app."""
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("brand_ipa", ROOT / "brand-ipa.py")
branding = importlib.util.module_from_spec(spec)
spec.loader.exec_module(branding)


class AlternateIconPackagingTests(unittest.TestCase):
    def test_icon_registration_payload_and_existing_icons(self):
        primary = {"CFBundleIconName": "Swiftgram", "CFBundleIconFiles": ["PrimaryIcon"]}
        existing = {"SGSky": {"CFBundleIconFiles": ["Sky"]}}
        plist = {
            "CFBundleIdentifier": "ph.telegra.Telegraph",
            "CFBundleIcons": {"CFBundlePrimaryIcon": primary, "CFBundleAlternateIcons": existing},
            "CFBundleIcons~ipad": {"CFBundlePrimaryIcon": primary, "CFBundleAlternateIcons": existing},
        }
        prefix = "Payload/Swiftgram.app/"
        with tempfile.TemporaryDirectory() as directory:
            source, target = [Path(directory) / name for name in ("input.ipa", "output.ipa")]
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr(prefix + "Info.plist", plistlib.dumps(plist))
                archive.writestr(prefix + "Swiftgram", b"binary unchanged")
                archive.writestr(prefix + "Assets.car", b"primary icon unchanged")
                archive.writestr(prefix + "PlugIns/Share.appex/Info.plist", plistlib.dumps({"CFBundleIdentifier": "ph.telegra.Telegraph.Share"}))
            branding.brand(source, target, build_number="42", commit="abcdef0123456789")
            with zipfile.ZipFile(target) as archive:
                result = plistlib.loads(archive.read(prefix + "Info.plist"))
                self.assertEqual(archive.read(prefix + "Swiftgram"), b"binary unchanged")
                self.assertEqual(archive.read(prefix + "Assets.car"), b"primary icon unchanged")
                self.assertEqual(len(archive.namelist()), len(set(archive.namelist())))
                for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
                    self.assertEqual(result[key]["CFBundlePrimaryIcon"], primary)
                    self.assertEqual(result[key]["CFBundleAlternateIcons"]["SGSky"], existing["SGSky"])
                    self.assertTrue(set(branding.CUSTOM_ICONS).issubset(result[key]["CFBundleAlternateIcons"]))
                for name in branding.CUSTOM_ICONS:
                    self.assertEqual(result["CFBundleIcons"]["CFBundleAlternateIcons"][name]["CFBundleIconFiles"], [name + "-60"])
                    for suffix, size in (("60@2x", 120), ("60@3x", 180), ("76", 76), ("76@2x", 152), ("83.5@2x", 167)):
                        filename = name + "-" + suffix + ".png"
                        data = archive.read(prefix + filename)
                        self.assertEqual(data, (branding.ICON_DIRECTORY / filename).read_bytes())
                        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                        self.assertEqual(struct.unpack(">II", data[16:24]), (size, size))
                        self.assertEqual(data[25], 2, "Home Screen icons must be opaque RGB")
                self.assertEqual(result["SGModBuildNumber"], "42")
                self.assertEqual(result["SGModCommit"], "abcdef0123456789")
                extension = plistlib.loads(archive.read(prefix + "PlugIns/Share.appex/Info.plist"))
                self.assertNotIn("CFBundleIcons", extension)
                self.assertNotIn("SGModBuildNumber", extension)


if __name__ == "__main__":
    unittest.main()
