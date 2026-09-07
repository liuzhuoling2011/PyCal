#!/bin/bash
# Import a Developer ID .p12 (base64) into a throwaway keychain for GitHub Actions.
# Required env: DEVELOPER_ID_P12_BASE64, DEVELOPER_ID_P12_PASSWORD
# Optional: APPLE_TEAM_ID, PYCAL_KEYCHAIN_PATH, PYCAL_KEYCHAIN_PASSWORD
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib-macos-release.sh
source "$script_dir/lib-macos-release.sh"

if [[ -z "${DEVELOPER_ID_P12_BASE64:-}" || -z "${DEVELOPER_ID_P12_PASSWORD:-}" ]]; then
    echo "DEVELOPER_ID_P12_BASE64 and DEVELOPER_ID_P12_PASSWORD are required." >&2
    exit 1
fi

keychain_path="${PYCAL_KEYCHAIN_PATH:-$RUNNER_TEMP/pycal-signing.keychain-db}"
if [[ -z "${RUNNER_TEMP:-}" ]]; then
    keychain_path="${PYCAL_KEYCHAIN_PATH:-$(mktemp -t pycal-signing).keychain-db}"
fi
keychain_password="${PYCAL_KEYCHAIN_PASSWORD:-$(openssl rand -base64 32)}"
p12_path="${RUNNER_TEMP:-/tmp}/pycal-developer-id.p12"
ca_dir="${RUNNER_TEMP:-/tmp}/pycal-apple-ca"

mkdir -p "$(dirname "$keychain_path")" "$ca_dir"
rm -f "$p12_path"
python3 - "$p12_path" <<'PY'
import base64, os, pathlib, sys
dest = pathlib.Path(sys.argv[1])
raw = "".join(os.environ.get("DEVELOPER_ID_P12_BASE64", "").split())
if not raw:
    raise SystemExit("DEVELOPER_ID_P12_BASE64 is empty")
dest.write_bytes(base64.b64decode(raw))
print(f"Decoded p12 ({dest.stat().st_size} bytes)")
PY

if [[ ! -s "$p12_path" ]]; then
    echo "Failed to decode DEVELOPER_ID_P12_BASE64" >&2
    exit 1
fi

security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"

# Developer ID signing needs Apple's intermediate in the search list.
for url in \
    "https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer" \
    "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer"
do
    name="$(basename "$url")"
    if curl -fsSL "$url" -o "$ca_dir/$name"; then
        security import "$ca_dir/$name" -k "$keychain_path" -T /usr/bin/codesign -T /usr/bin/security >/dev/null || true
    fi
done

security import "$p12_path" \
    -k "$keychain_path" \
    -P "$DEVELOPER_ID_P12_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productsign

security list-keychains -d user -s "$keychain_path" $(security list-keychains -d user | sed 's/"//g')
security default-keychain -s "$keychain_path"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path" >/dev/null

rm -f "$p12_path"

identity="$(pycal_find_developer_id_identity || true)"
if [[ -z "$identity" ]]; then
    echo "Imported the p12 but no Developer ID Application identity is visible." >&2
    echo "Export a Developer ID Application certificate (not Apple Development) including its private key." >&2
    security find-identity -v -p codesigning || true
    exit 1
fi

echo "Imported signing identity: $identity"
if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "CODESIGN_IDENTITY=$identity"
        echo "PYCAL_KEYCHAIN_PATH=$keychain_path"
        echo "PYCAL_KEYCHAIN_PASSWORD=$keychain_password"
    } >> "$GITHUB_ENV"
fi
