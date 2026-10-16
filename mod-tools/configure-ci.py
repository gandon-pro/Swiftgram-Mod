"""Generate local-only CI configuration; never print the API credentials."""
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path


def configure(root: Path, api_id: str, api_hash: str):
    if not re.fullmatch(r"[1-9][0-9]{0,9}", api_id) or not re.fullmatch(r"[0-9a-fA-F]{32}", api_hash):
        raise ValueError("Set valid TELEGRAM_API_ID and TELEGRAM_API_HASH repository secrets in Settings > Secrets and variables > Actions.")
    profile_data = subprocess.check_output([
        "openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in",
        str(root / "build-system/fake-codesigning/profiles/Telegram.mobileprovision")
    ], stderr=subprocess.DEVNULL)
    profile = plistlib.loads(profile_data)
    team_id = profile["TeamIdentifier"][0]
    app_identifier = profile["Entitlements"]["application-identifier"]
    if not app_identifier.startswith(team_id + "."):
        raise ValueError("Unexpected upstream test provisioning profile")
    config = json.loads((root / "build-system/template_minimal_development_configuration.json").read_text())
    config.update(bundle_id=app_identifier[len(team_id) + 1:], team_id=team_id,
                  api_id=api_id, api_hash=api_hash, is_internal_build="true", is_appstore_build="false")
    destination = root / "build-input/mod-ci-configuration.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(config, indent=2), encoding="utf-8")
    destination.chmod(0o600)
    return destination


if __name__ == "__main__":
    try:
        configure(Path(__file__).resolve().parents[1], os.environ.get("TELEGRAM_API_ID", "").strip(),
                  os.environ.get("TELEGRAM_API_HASH", "").strip())
    except ValueError as error:
        raise SystemExit(str(error))
    print("Build configuration created; API credentials are not included in the artifact.")
