#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this script on macOS with Xcode, not Windows." >&2
  exit 1
fi
config="${1:?Usage: bash mod-tools/prepare-macos.sh /absolute/path/to/configuration.json}"
python3 - "$config" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
for key in ('bundle_id', 'api_id', 'api_hash', 'team_id'):
    value = str(config.get(key, ''))
    if not value or '{!' in value:
        raise SystemExit('Fill configuration field: ' + key)
PY
echo "Required versions (from this checkout):"
cat versions.json
xcodebuild -version
git sparse-checkout disable
git submodule update --init --recursive
python3 build-system/Make/Make.py --cacheDir="$HOME/telegram-bazel-cache" generateProject \
  --configurationPath="$config" --xcodeManagedCodesigning
