#!/bin/bash
# Packaging-script sanity check: bash 3.2 `$version` + UTF-8 heredoc guard,
# plus a source-level check that Gatekeeper fallback helpers are not staged
# into the release DMG.
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

if grep -nE 'pycal_write_dmg_usage_note|安装到个人目录|首次打开\.command|使用说明\.txt' \
    "$script_dir/make-macos-dmg.sh" "$script_dir/lib-macos-release.sh"; then
    fail "packaging scripts still stage Gatekeeper fallback helpers into the DMG"
fi

if type pycal_write_dmg_usage_note >/dev/null 2>&1; then
    fail "pycal_write_dmg_usage_note should be removed (usage note is no longer in the DMG)"
fi

echo "OK: DMG packaging no longer stages usage note or Gatekeeper helpers"
