"""Set the install identity in the IPA that will be signed by the user's signing tool."""
import argparse
import plistlib
import re
import zipfile
from pathlib import Path, PurePosixPath

BUNDLE_ID = "ph.nigga.graph"
APP_NAME = "Niggagram"


def brand(source: Path, destination: Path):
    with zipfile.ZipFile(source) as archive:
        mains = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", name)]
        if len(mains) != 1:
            raise ValueError("Expected exactly one main application")
        main = mains[0]
        old_id = plistlib.loads(archive.read(main))["CFBundleIdentifier"]
        app_root = str(PurePosixPath(main).parent) + "/"

        def rewrite(value):
            if isinstance(value, dict):
                return {key: rewrite(item) for key, item in value.items()}
            if isinstance(value, list):
                return [rewrite(item) for item in value]
            if isinstance(value, str):
                for prefix in (old_id, "group." + old_id):
                    if value == prefix or value.startswith(prefix + "."):
                        return value.replace(old_id, BUNDLE_ID, 1)
            return value

        destination.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as output:
            for info in archive.infolist():
                data = archive.read(info)
                if info.filename.startswith(app_root) and info.filename.endswith("/Info.plist"):
                    plist = rewrite(plistlib.loads(data))
                    if info.filename == main:
                        plist["CFBundleDisplayName"] = APP_NAME
                        plist["CFBundleName"] = APP_NAME
                    data = plistlib.dumps(plist, fmt=plistlib.FMT_BINARY)
                elif info.filename.startswith(app_root) and info.filename.endswith(".lproj/InfoPlist.strings"):
                    try:
                        plist = plistlib.loads(data)
                    except plistlib.InvalidFileException:
                        # Source-format strings are normally compiled by Xcode.
                        text = data.decode("utf-8-sig")
                        text = re.sub(r'("CFBundle(?:DisplayName|Name)"\s*=\s*)"[^"]*"', r'\1"' + APP_NAME + '"', text)
                        data = text.encode("utf-8")
                    else:
                        for key in ("CFBundleDisplayName", "CFBundleName"):
                            if key in plist:
                                plist[key] = APP_NAME
                        data = plistlib.dumps(plist, fmt=plistlib.FMT_BINARY)
                output.writestr(info, data)
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        plist = plistlib.loads(archive.read(main))
        assert plist["CFBundleIdentifier"] == BUNDLE_ID
        assert plist["CFBundleDisplayName"] == APP_NAME
    print(f"Prepared {APP_NAME}: {BUNDLE_ID}. The IPA requires a new signature.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    brand(args.source, args.destination)
