"""Convert the user-supplied JPEG into Icon Composer's 1024 px PNG input on macOS."""
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "Swiftgram/SGSettingsUI/Images.xcassets/ModPrivacy.imageset/icon.jpg"
destination = root / "Telegram/Telegram-iOS/Swiftgram.icon/Assets/ModIcon.png"
subprocess.run(["sips", "-s", "format", "png", "--resampleHeightWidth", "1024", "1024", str(source), "--out", str(destination)], check=True)
