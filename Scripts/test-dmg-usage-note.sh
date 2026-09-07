#!/bin/bash
# Regression check for the bash 3.2 `$version（` / set -u crash that aborted
# Package DMG after notarization (tag v0.1.0, run 34127587132).
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib-macos-release.sh
source "$script_dir/lib-macos-release.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# Guard the packaging script: no unquoted heredoc may expand $version next to UTF-8.
if python3 - "$script_dir/make-macos-dmg.sh" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
# Unquoted <<NOTE was the failing form. Quoted <<'NOTE' / <<'EOF' are fine.
bad = []
in_unquoted = False
for i, line in enumerate(text.splitlines(), 1):
    stripped = line.lstrip()
    if stripped.startswith("<<") and not stripped.startswith("<<'") and not stripped.startswith('<<"'):
        in_unquoted = True
    if in_unquoted and "$version" in line:
        idx = line.find("$version")
        after = line[idx + len("$version"):idx + len("$version") + 1]
        if after and not after.isalnum() and after not in "_.\"'}] \t":
            # Allow $version at EOL or followed by ASCII punctuation that is not UTF-8.
            if after.encode("utf-8")[0] >= 0x80:
                bad.append(f"{i}:{line}")
    if stripped == "NOTE" or stripped == "EOF":
        in_unquoted = False
if bad:
    print("unquoted $version next to non-ASCII:")
    print("\n".join(bad))
    sys.exit(1)
print("make-macos-dmg.sh: no unquoted $version+UTF-8 interpolations")
PY
then
    :
else
    fail "make-macos-dmg.sh still interpolates \$version next to UTF-8 in an unquoted heredoc"
fi

bash -n "$script_dir/make-macos-dmg.sh"
bash -n "$script_dir/lib-macos-release.sh"
echo "bash -n: ok"

stage="$(mktemp -d /tmp/pycal-usage-note.XXXXXX)"
trap 'rm -rf "$stage"' EXIT

notarized_note="$stage/使用说明-notarized.txt"
unsigned_note="$stage/使用说明-unsigned.txt"

# Chinese destination path + set -u, same as CI after stapling the helper app.
set -u
pycal_write_dmg_usage_note "$notarized_note" "0.1.0" 1
pycal_write_dmg_usage_note "$unsigned_note" "0.1.0" 0

grep -Fqx "PyCal 0.1.0（已 Developer ID 签名并公证）" "$notarized_note" \
    || fail "notarized header missing version"
grep -Fqx "PyCal 0.1.0（未公证，双击通常会被拦截）" "$unsigned_note" \
    || fail "unsigned header missing version"
grep -F "不要关闭系统完整性保护" "$notarized_note" >/dev/null \
    || fail "notarized body truncated"
grep -F "docs/release.md" "$unsigned_note" >/dev/null \
    || fail "unsigned body truncated"

if pycal_write_dmg_usage_note "$stage/empty.txt" "" 1 2>/dev/null; then
    fail "empty version should be rejected under set -u"
fi

echo "usage notes:"
echo "---- notarized ----"
cat "$notarized_note"
echo "---- unsigned ----"
cat "$unsigned_note"
echo "OK"
