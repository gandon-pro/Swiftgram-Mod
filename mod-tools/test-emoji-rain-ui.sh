#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
app="$work/EmojiRainTest.app"
mkdir -p "$app"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.swiftgram.emoji-rain-tests</string>
<key>CFBundleExecutable</key><string>EmojiRainTest</string>
<key>CFBundleName</key><string>EmojiRainTest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UILaunchScreen</key><dict/>
</dict></plist>
PLIST
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator swiftc -sdk "$sdk" -target "$(uname -m)-apple-ios17.0-simulator" \
  -D PEERINFO_EMOJI_RAIN_TESTS \
  "$root/submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoEmojiRainOverlay.swift" \
  "$root/mod-tools/tests/PeerInfoEmojiRainUIKitTests.swift" -o "$app/EmojiRainTest"
codesign --force --sign - --timestamp=none "$app"
device="$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for group in d["devices"].values() for x in group if "iPhone" in x["name"]))')"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
xcrun simctl launch "$device" org.swiftgram.emoji-rain-tests
container="$(xcrun simctl get_app_container "$device" org.swiftgram.emoji-rain-tests data)"
for attempt in $(seq 1 90); do
  if [[ -s "$container/Documents/rain-ui-result.json" ]]; then
    cat "$container/Documents/rain-ui-result.json"
    python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["passed"] else 1)' "$container/Documents/rain-ui-result.json"
    exit 0
  fi
  sleep 1
done
echo 'Emoji rain simulator test timed out' >&2
exit 1
