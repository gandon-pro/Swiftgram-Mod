"""Renew the repository's self-signed CI provisioning profiles.

These profiles are only for compiling an IPA that users re-sign themselves.
No Apple Developer account or production signing identity is involved.
"""

import argparse
import datetime as dt
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILES = ROOT / "build-system/fake-codesigning/profiles"
CERTS = ROOT / "build-system/fake-codesigning/certs"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs).stdout


def decode(openssl, path):
    return plistlib.loads(run(openssl, "cms", "-verify", "-inform", "DER", "-noverify", "-in", str(path)))


def renew(openssl, expiry):
    profiles = sorted(PROFILES.glob("*.mobileprovision"))
    if not profiles:
        raise ValueError(f"No provisioning profiles in {PROFILES}")
    public_cert = (CERTS / "Public.cer").read_bytes()
    cert_end = run(openssl, "x509", "-inform", "DER", "-in", str(CERTS / "Public.cer"), "-noout", "-enddate")
    valid_until = dt.datetime.strptime(cert_end.decode().strip().split("=", 1)[1], "%b %d %H:%M:%S %Y %Z")
    if expiry >= valid_until:
        raise ValueError(f"Profile expiry must precede certificate expiry {valid_until} UTC")

    with tempfile.TemporaryDirectory(prefix="swiftgram-profiles-") as temp:
        temp = Path(temp)
        cert = temp / "cert.pem"
        key = temp / "key.pem"
        p12 = CERTS / "SelfSigned.p12"
        run(openssl, "pkcs12", "-legacy", "-in", str(p12), "-passin", "pass:", "-clcerts", "-nokeys", "-out", str(cert))
        run(openssl, "pkcs12", "-legacy", "-in", str(p12), "-passin", "pass:", "-nocerts", "-nodes", "-out", str(key))
        now = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None, microsecond=0)
        staged = []
        for source in profiles:
            profile = decode(openssl, source)
            if profile.get("DeveloperCertificates") != [public_cert]:
                raise ValueError(f"Unexpected signing certificate in {source.name}")
            profile["CreationDate"] = now
            profile["ExpirationDate"] = expiry
            profile["TimeToLive"] = (expiry - now).days
            plist = temp / (source.stem + ".plist")
            output = temp / source.name
            plist.write_bytes(plistlib.dumps(profile, fmt=plistlib.FMT_XML))
            run(openssl, "cms", "-sign", "-binary", "-nodetach", "-in", str(plist),
                "-signer", str(cert), "-inkey", str(key), "-outform", "DER", "-out", str(output))
            checked = decode(openssl, output)
            if checked["ExpirationDate"] != expiry or checked["Entitlements"] != profile["Entitlements"]:
                raise ValueError(f"Renewed profile verification failed: {source.name}")
            staged.append((source, output))
        for source, output in staged:
            shutil.copyfile(output, source)
            print(f"renewed {source.name} to {expiry.isoformat()} UTC")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--openssl", default="openssl")
    parser.add_argument("--expires", default="2029-10-01", help="UTC date, before the test certificate expires")
    args = parser.parse_args()
    renew(args.openssl, dt.datetime.strptime(args.expires, "%Y-%m-%d"))
