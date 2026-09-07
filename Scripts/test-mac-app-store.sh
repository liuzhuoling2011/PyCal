#!/bin/bash
# Static checks for Mac App Store readiness. Does not call Apple, xcodebuild, or
# notarytool, and does not require certificates.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

bash -n "$script_dir/archive-mac-app-store.sh" || fail "archive-mac-app-store.sh failed bash -n"
bash -n "$script_dir/build-macos-app.sh" || fail "build-macos-app.sh failed bash -n"
echo "bash -n: ok"

python3 - "$root_dir" <<'PY' || exit 1
import pathlib
import plistlib
import re
import sys

root = pathlib.Path(sys.argv[1])

def load_plist(path: pathlib.Path):
    try:
        with path.open("rb") as fh:
            return plistlib.load(fh)
    except Exception as exc:  # pragma: no cover - exercised by bad fixtures
        print(f"FAIL: cannot parse {path}: {exc}", file=sys.stderr)
        sys.exit(1)

ent = load_plist(root / "PyCal.entitlements")
if ent != {"com.apple.security.app-sandbox": True}:
    print(f"FAIL: entitlements must be sandbox-only, got {ent!r}", file=sys.stderr)
    sys.exit(1)

forbidden = (
    "com.apple.security.cs.disable-library-validation",
    "com.apple.security.cs.allow-unsigned-executable-memory",
    "com.apple.security.cs.allow-jit",
    "com.apple.security.get-task-allow",
    "com.apple.security.temporary-exception",
    "com.apple.security.network.",
    "com.apple.security.files.",
    "com.apple.security.device.",
    "com.apple.security.automation.",
)
for key in ent:
    if any(key == item or key.startswith(item) for item in forbidden if item.endswith(".")) or key in forbidden:
        print(f"FAIL: forbidden or extra MAS entitlement {key}", file=sys.stderr)
        sys.exit(1)

export = load_plist(root / "Scripts/ExportOptions-AppStore.plist")
if export.get("method") != "app-store-connect":
    print(f"FAIL: export method must be app-store-connect, got {export.get('method')!r}", file=sys.stderr)
    sys.exit(1)
if export.get("destination") != "export":
    print(f"FAIL: committed export destination must be export, got {export.get('destination')!r}", file=sys.stderr)
    sys.exit(1)
if export.get("signingStyle") != "automatic":
    print("FAIL: export signingStyle must be automatic", file=sys.stderr)
    sys.exit(1)
if export.get("teamID") != "B5W7AL6CG9":
    print(f"FAIL: unexpected teamID {export.get('teamID')!r}", file=sys.stderr)
    sys.exit(1)

privacy = load_plist(root / "Sources/PyCal/PrivacyInfo.xcprivacy")
if privacy.get("NSPrivacyTracking") is not False:
    print("FAIL: NSPrivacyTracking must be false", file=sys.stderr)
    sys.exit(1)
if privacy.get("NSPrivacyCollectedDataTypes") != []:
    print("FAIL: no collected data types expected", file=sys.stderr)
    sys.exit(1)
reasons = privacy.get("NSPrivacyAccessedAPITypes") or []
file_ts = next((item for item in reasons if item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryFileTimestamp"), None)
if not file_ts or "C617.1" not in file_ts.get("NSPrivacyAccessedAPITypeReasons", []):
    print("FAIL: PrivacyInfo must declare FileTimestamp C617.1", file=sys.stderr)
    sys.exit(1)

info = load_plist(root / "Scripts/PyCal-Info.plist")
if info.get("CFBundleIdentifier") != "com.liuzhuoling.pycal":
    print("FAIL: Scripts/PyCal-Info.plist bundle id", file=sys.stderr)
    sys.exit(1)
if "dev.pycal.app" in (root / "PyCal.xcodeproj/project.pbxproj").read_text(encoding="utf-8"):
    print("FAIL: project.pbxproj still references abandoned bundle id dev.pycal.app", file=sys.stderr)
    sys.exit(1)
if info.get("ITSAppUsesNonExemptEncryption") is not False:
    print("FAIL: Scripts/PyCal-Info.plist must set ITSAppUsesNonExemptEncryption=false", file=sys.stderr)
    sys.exit(1)

pbx = (root / "PyCal.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
for needle in (
    "CODE_SIGN_ENTITLEMENTS = PyCal.entitlements;",
    "ENABLE_APP_SANDBOX = YES;",
    "ENABLE_HARDENED_RUNTIME = YES;",
    "PRODUCT_BUNDLE_IDENTIFIER = com.liuzhuoling.pycal;",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;",
    'INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";',
):
    if needle not in pbx:
        print(f"FAIL: project.pbxproj missing {needle}", file=sys.stderr)
        sys.exit(1)
if pbx.count("CODE_SIGN_ENTITLEMENTS = PyCal.entitlements;") < 2:
    print("FAIL: entitlements must be set on Debug and Release", file=sys.stderr)
    sys.exit(1)

dmg_build = (root / "Scripts/build-macos-app.sh").read_text(encoding="utf-8")
if "CODE_SIGNING_ALLOWED=NO" not in dmg_build:
    print("FAIL: DMG build must keep CODE_SIGNING_ALLOWED=NO", file=sys.stderr)
    sys.exit(1)
if re.search(r"codesign\s+.*--entitlements", dmg_build):
    print("FAIL: DMG codesign must not pass --entitlements (keeps Application Support unsandboxed)", file=sys.stderr)
    sys.exit(1)

workflow = (root / ".github/workflows/release-dmg.yml").read_text(encoding="utf-8")
if "archive-mac-app-store.sh" in workflow or "exportArchive" in workflow:
    print("FAIL: DMG workflow must not grow a MAS export/upload step", file=sys.stderr)
    sys.exit(1)

archive = (root / "Scripts/archive-mac-app-store.sh").read_text(encoding="utf-8")
if "notarytool" in archive and "Do not" not in archive:
    print("FAIL: archive script should not invoke notarytool", file=sys.stderr)
    sys.exit(1)
if re.search(r"\bnotarytool submit\b", archive) or re.search(r"\bstapler staple\b", archive):
    print("FAIL: archive script must not submit to notarytool/stapler", file=sys.stderr)
    sys.exit(1)
if "generic/platform=macOS" not in archive:
    print("FAIL: archive script must pin macOS destination", file=sys.stderr)
    sys.exit(1)

pkg = (root / "Package.swift").read_text(encoding="utf-8")
if "PrivacyInfo.xcprivacy" not in pkg:
    print("FAIL: Package.swift should ship PrivacyInfo.xcprivacy", file=sys.stderr)
    sys.exit(1)

print("entitlements: sandbox-only")
print("export options: app-store-connect / automatic / export")
print("privacy manifest: no tracking, FileTimestamp C617.1")
print("xcodeproj: sandbox + hardened runtime + com.liuzhuoling.pycal")
print("DMG path: still unsigned-then-Developer-ID, no entitlements")
print("OK")
PY
